#!/usr/bin/env python3
"""Build and validate deterministic fitted garment layers for a rig pet."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import tempfile
import uuid
from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


CHROMA = (255, 0, 255)
SOURCE_CHROMA_TOLERANCE = 48
CHROMA_CLEAR_TOLERANCE = 104
# Deliberately independent and stricter than the source-key threshold. Do not
# alias QA to cleanup: QA must remain able to catch cleanup regressions.
QA_CHROMA_TOLERANCE = 96
EDGE_DESPILL_TOLERANCE = 160
SOURCE_BACKGROUND_NORMALIZE_TOLERANCE = 64
MIN_POSTURE_IOU = 0.94
MAX_OUTSIDE_ROI_CHANGE = 0.08


@dataclass(frozen=True)
class GarmentRule:
    anchor: str
    diff_threshold: int
    width_expansion: float
    top_expansion: float
    bottom_expansion: float
    minimum_coverage: float
    maximum_delta_e: float


@dataclass(frozen=True)
class GarmentSpec:
    anchor: str
    roi: tuple[int, int, int, int]
    core: tuple[int, int, int, int]
    anchor_region: tuple[int, int, int, int]
    diff_threshold: int
    minimum_coverage: float
    maximum_delta_e: float


RULES = {
    # Coverage is measured against the base pet's opaque region, so these
    # limits are independent of canvas size and species. Colour limits are
    # CIE76 distances from the matching published Choco layer.
    "wool_hat": GarmentRule("head", 56, 0.65, 0.60, 0.08, 0.045, 10.0),
    "straw_hat": GarmentRule("head", 56, 0.75, 0.45, 0.08, 0.040, 18.0),
    "party_hat": GarmentRule("head", 56, 0.35, 0.85, 0.05, 0.025, 20.0),
    "red_scarf": GarmentRule("neck", 64, 0.45, 0.18, 0.70, 0.040, 10.0),
    "plaid_scarf": GarmentRule("neck", 64, 0.45, 0.18, 0.70, 0.040, 18.0),
    "bell_collar": GarmentRule("neck", 64, 0.30, 0.12, 0.48, 0.0095, 20.0),
}


PROMPT_REQUIREMENTS = (
    "The garment must be conspicuous and read immediately at sprite scale. "
    "A hat must visibly cover the top of the head; a scarf or collar must wrap "
    "visibly around the neck. Preserve the garment's canonical Choco colour "
    "palette exactly (the red scarf must remain clearly red). Never shrink the "
    "garment into a decorative dot, tiny badge, stain, or isolated fragment. "
    "For small-headed, slender pets such as Tabby, size the garment relative "
    "to the head: hats must span at least half the head width and neckwear must "
    "form an unmistakable band across the neck."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--worn-dir", type=Path, required=True)
    parser.add_argument(
        "--retry-worn-dir",
        type=Path,
        help=(
            "Optional second set of generated worn images. A garment rejected "
            "from --worn-dir is retried from here; if that also fails, the "
            "entire batch fails atomically."
        ),
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--qa-dir", type=Path, required=True)
    parser.add_argument("--pet-id")
    parser.add_argument("--rig", type=Path)
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Run all QA and update QA artifacts without replacing garment assets.",
    )
    parser.add_argument(
        "--canonical-garment-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "assets"
        / "pets"
        / "choco"
        / "garments",
        help="Published Choco layers used as the canonical colour reference.",
    )
    parser.add_argument(
        "--preserve-existing",
        action="append",
        default=[],
        choices=RULES,
        help="Copy this already-published layer unchanged into the validated set.",
    )
    return parser.parse_args()


def binary_alpha(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(lambda value: 255 if value > 128 else 0)


def chroma_mask(image: Image.Image, tolerance: int) -> Image.Image:
    pixels = []
    for red, green, blue, alpha in image.get_flattened_data():
        distance = max(255 - red, green, 255 - blue)
        pixels.append(255 if alpha and distance <= tolerance else 0)
    mask = Image.new("L", image.size)
    mask.putdata(pixels)
    return mask


def chroma_foreground(image: Image.Image) -> Image.Image:
    return ImageChops.invert(chroma_mask(image, SOURCE_CHROMA_TOLERANCE))


def normalize_chroma_background(image: Image.Image) -> Image.Image:
    """Flood-fill near-magenta edge background to the exact source key."""
    result = image.copy()
    pixels = result.load()
    width, height = result.size
    queue = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        red, green, blue, alpha = pixels[x, y]
        distance = max(255 - red, green, 255 - blue)
        if not alpha or distance > SOURCE_BACKGROUND_NORMALIZE_TOLERANCE:
            continue
        pixels[x, y] = (*CHROMA, 255)
        for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= point[0] < width and 0 <= point[1] < height:
                queue.append(point)
    return result


def max_rgb_difference(left: Image.Image, right: Image.Image) -> Image.Image:
    red, green, blue = ImageChops.difference(
        left.convert("RGB"), right.convert("RGB")
    ).split()
    return ImageChops.lighter(ImageChops.lighter(red, green), blue)


def shifted(image: Image.Image, dx: int, dy: int, fill: tuple[int, ...]) -> Image.Image:
    result = Image.new(image.mode, image.size, fill)
    result.paste(image, (dx, dy))
    return result


def count_mask(mask: Image.Image) -> int:
    return mask.histogram()[255]


def _srgb_channel(value: int) -> float:
    channel = value / 255.0
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def rgb_to_lab(red: int, green: int, blue: int) -> tuple[float, float, float]:
    red_linear, green_linear, blue_linear = (
        _srgb_channel(red),
        _srgb_channel(green),
        _srgb_channel(blue),
    )
    x = (
        red_linear * 0.4124564
        + green_linear * 0.3575761
        + blue_linear * 0.1804375
    ) / 0.95047
    y = (
        red_linear * 0.2126729
        + green_linear * 0.7151522
        + blue_linear * 0.0721750
    )
    z = (
        red_linear * 0.0193339
        + green_linear * 0.1191920
        + blue_linear * 0.9503041
    ) / 1.08883

    def pivot(value: float) -> float:
        if value > 0.008856:
            return value ** (1.0 / 3.0)
        return 7.787 * value + 16.0 / 116.0

    x_pivot, y_pivot, z_pivot = pivot(x), pivot(y), pivot(z)
    return (
        116.0 * y_pivot - 16.0,
        500.0 * (x_pivot - y_pivot),
        200.0 * (y_pivot - z_pivot),
    )


def dominant_lab(image: Image.Image) -> tuple[float, float, float]:
    """Return the mean chromatic garment tone, excluding outlines/highlights."""
    samples = []
    for red, green, blue, alpha in image.get_flattened_data():
        if alpha <= 128:
            continue
        lightness, a_axis, b_axis = rgb_to_lab(red, green, blue)
        chroma = math.hypot(a_axis, b_axis)
        if 22.0 <= lightness <= 92.0 and chroma >= 18.0:
            samples.append((lightness, a_axis, b_axis))
    if not samples:
        raise ValueError("garment has no measurable chromatic main tone")
    return tuple(
        sum(sample[index] for sample in samples) / len(samples)
        for index in range(3)
    )


def lab_distance(
    left: tuple[float, float, float], right: tuple[float, float, float]
) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def mask_iou(left: Image.Image, right: Image.Image) -> float:
    intersection = count_mask(ImageChops.multiply(left, right))
    union = count_mask(ImageChops.lighter(left, right))
    return intersection / union if union else 1.0


def align_to_base(
    base_mask: Image.Image, worn: Image.Image
) -> tuple[Image.Image, Image.Image, int, int, float]:
    worn_mask = chroma_foreground(worn)
    base_small = base_mask.resize((256, 256), Image.Resampling.NEAREST)
    worn_small = worn_mask.resize((256, 256), Image.Resampling.NEAREST)
    best = (-1.0, 0, 0)
    for small_dy in range(-4, 5):
        for small_dx in range(-4, 5):
            candidate = shifted(worn_small, small_dx, small_dy, 0)
            score = mask_iou(base_small, candidate)
            if score > best[0]:
                best = (score, small_dx, small_dy)
    _score, small_dx, small_dy = best
    dx = round(small_dx * worn.width / 256)
    dy = round(small_dy * worn.height / 256)
    aligned = shifted(worn, dx, dy, (*CHROMA, 255))
    aligned_mask = chroma_foreground(aligned)
    return aligned, aligned_mask, dx, dy, mask_iou(base_mask, aligned_mask)


def rect_mask(
    size: tuple[int, int], rect: tuple[int, int, int, int]
) -> Image.Image:
    mask = Image.new("L", size)
    ImageDraw.Draw(mask).rectangle(rect, fill=255)
    return mask


def components(
    mask: Image.Image,
) -> list[tuple[int, tuple[int, int, int, int], set[tuple[int, int]]]]:
    width, height = mask.size
    pixels = mask.load()
    seen: set[tuple[int, int]] = set()
    found = []
    for y in range(height):
        for x in range(width):
            if not pixels[x, y] or (x, y) in seen:
                continue
            queue = deque([(x, y)])
            seen.add((x, y))
            points: set[tuple[int, int]] = set()
            min_x = max_x = x
            min_y = max_y = y
            while queue:
                px, py = queue.popleft()
                points.add((px, py))
                min_x = min(min_x, px)
                min_y = min(min_y, py)
                max_x = max(max_x, px)
                max_y = max(max_y, py)
                for nx, ny in (
                    (px - 1, py),
                    (px + 1, py),
                    (px, py - 1),
                    (px, py + 1),
                ):
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and pixels[nx, ny]
                        and (nx, ny) not in seen
                    ):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            found.append(
                (len(points), (min_x, min_y, max_x + 1, max_y + 1), points)
            )
    return found


def intersects(
    left: tuple[int, int, int, int], right: tuple[int, int, int, int]
) -> bool:
    return (
        left[0] < right[2]
        and left[2] > right[0]
        and left[1] < right[3]
        and left[3] > right[1]
    )


def _clamped_rect(
    rect: tuple[float, float, float, float], size: tuple[int, int]
) -> tuple[int, int, int, int]:
    width, height = size
    return (
        max(0, round(rect[0])),
        max(0, round(rect[1])),
        min(width - 1, round(rect[2])),
        min(height - 1, round(rect[3])),
    )


def _head_box(base: Image.Image, rig_path: Path) -> tuple[int, int, int, int]:
    if rig_path.is_file():
        rig = json.loads(rig_path.read_text())
        raw = rig.get("front", {}).get("boxes", {}).get("head")
        if isinstance(raw, list) and len(raw) == 4:
            return tuple(int(value) for value in raw)
    bounds = binary_alpha(base).getbbox()
    if bounds is None:
        raise ValueError("Base pose is empty")
    left, top, right, bottom = bounds
    return (left, top, right, round(top + (bottom - top) * 0.55))


def build_specs(base: Image.Image, rig_path: Path) -> dict[str, GarmentSpec]:
    left, top, right, bottom = _head_box(base, rig_path)
    head_width = right - left
    head_height = bottom - top
    specs = {}
    for garment_id, rule in RULES.items():
        if rule.anchor == "head":
            roi = _clamped_rect(
                (
                    left - head_width * rule.width_expansion,
                    top - head_height * rule.top_expansion,
                    right + head_width * rule.width_expansion,
                    bottom + head_height * rule.bottom_expansion,
                ),
                base.size,
            )
            core = _clamped_rect(
                (
                    left - head_width * 0.15,
                    top - head_height * 0.45,
                    right + head_width * 0.15,
                    bottom,
                ),
                base.size,
            )
            anchor_region = _clamped_rect(
                (
                    left,
                    top - head_height * 0.65,
                    right,
                    top + head_height * 0.55,
                ),
                base.size,
            )
        else:
            roi = _clamped_rect(
                (
                    left - head_width * rule.width_expansion,
                    bottom - head_height * rule.top_expansion,
                    right + head_width * rule.width_expansion,
                    bottom + head_height * rule.bottom_expansion,
                ),
                base.size,
            )
            core = _clamped_rect(
                (
                    left,
                    bottom - head_height * 0.12,
                    right,
                    bottom + head_height * 0.42,
                ),
                base.size,
            )
            anchor_region = _clamped_rect(
                (
                    (left + right) / 2 - head_width * 0.30,
                    bottom - head_height * 0.15,
                    (left + right) / 2 + head_width * 0.30,
                    bottom + head_height * 0.55,
                ),
                base.size,
            )
        specs[garment_id] = GarmentSpec(
            rule.anchor,
            roi,
            core,
            anchor_region,
            rule.diff_threshold,
            rule.minimum_coverage,
            rule.maximum_delta_e,
        )
    return specs


def lock_outside_roi(
    base: Image.Image,
    worn: Image.Image,
    roi: tuple[int, int, int, int],
) -> Image.Image:
    """Restore the immutable pose outside the edit ROI after model resizing."""
    locked = Image.new("RGBA", base.size, (*CHROMA, 255))
    locked.alpha_composite(base)
    locked.paste(worn.crop(roi), (roi[0], roi[1]))
    return locked


def _despill_edges(layer: Image.Image) -> Image.Image:
    alpha = binary_alpha(layer)
    edge = ImageChops.subtract(alpha, alpha.filter(ImageFilter.MinFilter(5)))
    suspicious = ImageChops.multiply(
        edge, chroma_mask(layer, EDGE_DESPILL_TOLERANCE)
    )
    pixels = layer.load()
    alpha_pixels = alpha.load()
    suspicious_pixels = suspicious.load()
    for y in range(layer.height):
        for x in range(layer.width):
            if not suspicious_pixels[x, y]:
                continue
            replacement = None
            for radius in range(1, 9):
                for nx, ny in (
                    (x - radius, y),
                    (x + radius, y),
                    (x, y - radius),
                    (x, y + radius),
                ):
                    if not (0 <= nx < layer.width and 0 <= ny < layer.height):
                        continue
                    if not alpha_pixels[nx, ny]:
                        continue
                    red, green, blue, _alpha = pixels[nx, ny]
                    if max(255 - red, green, 255 - blue) > EDGE_DESPILL_TOLERANCE:
                        replacement = (red, green, blue, 255)
                        break
                if replacement is not None:
                    break
            if replacement is not None:
                pixels[x, y] = replacement
            else:
                pixels[x, y] = (0, 0, 0, 0)
    return layer


def clean_chroma(layer: Image.Image) -> Image.Image:
    pixels = layer.load()
    for y in range(layer.height):
        for x in range(layer.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha == 0
                or max(255 - red, green, 255 - blue)
                <= CHROMA_CLEAR_TOLERANCE
            ):
                pixels[x, y] = (0, 0, 0, 0)
    layer = _despill_edges(layer)
    pixels = layer.load()
    for y in range(layer.height):
        for x in range(layer.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return layer


def extract_layer(
    base: Image.Image,
    worn: Image.Image,
    foreground: Image.Image,
    spec: GarmentSpec,
) -> Image.Image:
    difference = max_rgb_difference(base, worn)
    changed = difference.point(
        lambda value: 255 if value > spec.diff_threshold else 0
    )
    changed = ImageChops.multiply(changed, foreground)
    changed = ImageChops.multiply(changed, rect_mask(base.size, spec.roi))
    connected = changed.filter(ImageFilter.MaxFilter(9))
    candidates = [
        component
        for component in components(connected)
        if intersects(component[1], spec.core)
    ]
    if not candidates:
        raise ValueError("No garment component intersects the expected anchor core")
    _area, _box, selected_points = max(
        candidates, key=lambda component: component[0]
    )
    selected = Image.new("L", base.size)
    selected_pixels = selected.load()
    for x, y in selected_points:
        selected_pixels[x, y] = 255
    garment_mask = ImageChops.multiply(changed, selected)
    garment_mask = garment_mask.filter(ImageFilter.MaxFilter(5)).filter(
        ImageFilter.MinFilter(5)
    )
    garment_mask = ImageChops.multiply(garment_mask, foreground)
    garment_mask = ImageChops.multiply(
        garment_mask, rect_mask(base.size, spec.roi)
    )
    layer = Image.new("RGBA", base.size)
    opaque_worn = worn.copy()
    opaque_worn.putalpha(255)
    layer.paste(opaque_worn, (0, 0), garment_mask)
    return clean_chroma(layer)


def outside_roi_change_fraction(
    base: Image.Image,
    worn: Image.Image,
    foreground: Image.Image,
    roi: tuple[int, int, int, int],
) -> float:
    changed = max_rgb_difference(base, worn).point(
        lambda value: 255 if value > 96 else 0
    )
    common = ImageChops.multiply(binary_alpha(base), foreground)
    outside = ImageChops.invert(rect_mask(base.size, roi))
    denominator = count_mask(ImageChops.multiply(common, outside))
    numerator = count_mask(
        ImageChops.multiply(ImageChops.multiply(changed, common), outside)
    )
    return numerator / denominator if denominator else 0.0


def posture_iou_outside_roi(
    base_mask: Image.Image,
    worn_foreground: Image.Image,
    roi: tuple[int, int, int, int],
) -> float:
    """Compare pet silhouettes only where a garment is forbidden to change them."""
    outside = ImageChops.invert(rect_mask(base_mask.size, roi))
    return mask_iou(
        ImageChops.multiply(base_mask, outside),
        ImageChops.multiply(worn_foreground, outside),
    )


def validate_garment_layer(
    garment_id: str,
    layer: Image.Image,
    base_pet_pixels: int,
    spec: GarmentSpec,
    canonical_tone: tuple[float, float, float],
) -> dict[str, object]:
    if layer.size[0] <= 0 or layer.size[1] <= 0:
        raise ValueError(f"{garment_id}: layer canvas is empty")
    alpha_pixels = count_mask(binary_alpha(layer))
    if alpha_pixels == 0:
        raise ValueError(f"{garment_id}: extracted layer is empty")
    coverage = alpha_pixels / base_pet_pixels if base_pet_pixels else 0.0
    if coverage < spec.minimum_coverage:
        raise ValueError(
            f"{garment_id}: garment coverage {coverage:.2%} is below "
            f"the {spec.minimum_coverage:.2%} base-pet minimum"
        )

    bounds = layer.getbbox()
    if bounds is None:
        raise ValueError(f"{garment_id}: extracted layer has no bounding box")
    center_x = (bounds[0] + bounds[2]) / 2.0
    center_y = (bounds[1] + bounds[3]) / 2.0
    anchor_left, anchor_top, anchor_right, anchor_bottom = spec.anchor_region
    if not (
        anchor_left <= center_x <= anchor_right
        and anchor_top <= center_y <= anchor_bottom
    ):
        raise ValueError(
            f"{garment_id}: layer bounds {bounds} are outside the "
            f"{spec.anchor} anchor region {spec.anchor_region}"
        )

    observed_tone = dominant_lab(layer)
    delta_e = lab_distance(observed_tone, canonical_tone)
    if delta_e > spec.maximum_delta_e:
        raise ValueError(
            f"{garment_id}: canonical colour deltaE {delta_e:.2f} exceeds "
            f"the {spec.maximum_delta_e:.2f} limit"
        )
    return {
        "layerBounds": bounds,
        "anchorRegion": spec.anchor_region,
        "anchorBoundsPassed": True,
        "alphaPixels": alpha_pixels,
        "basePetPixels": base_pet_pixels,
        "coverageFraction": round(coverage, 6),
        "minimumCoverageFraction": spec.minimum_coverage,
        "dominantLab": [round(value, 3) for value in observed_tone],
        "canonicalLab": [round(value, 3) for value in canonical_tone],
        "canonicalColourDeltaE": round(delta_e, 3),
        "maximumCanonicalColourDeltaE": spec.maximum_delta_e,
    }


def make_contact_sheet(
    base: Image.Image,
    rows: list[tuple[str, Image.Image, Image.Image]],
    output: Path,
) -> None:
    thumb_size = 256
    sheet = Image.new(
        "RGB", (thumb_size * 3, len(rows) * (thumb_size + 28)), "#202124"
    )
    draw = ImageDraw.Draw(sheet)
    for row, (garment_id, worn, layer) in enumerate(rows):
        y = row * (thumb_size + 28)
        composite = base.copy()
        composite.alpha_composite(layer)
        for column, image in enumerate((base, worn, composite)):
            preview = image.convert("RGBA").resize(
                (thumb_size, thumb_size), Image.Resampling.NEAREST
            )
            background = Image.new("RGBA", preview.size, "#F2F2F2")
            background.alpha_composite(preview)
            sheet.paste(background.convert("RGB"), (column * thumb_size, y))
        draw.text(
            (8, y + thumb_size + 6),
            f"{garment_id}: base | worn | extracted",
            fill="white",
        )
    sheet.save(output)


def _atomic_replace_directory(staged: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    backup = target.parent / f".{target.name}.backup-{uuid.uuid4().hex}"
    had_target = target.exists()
    if had_target:
        os.replace(target, backup)
    try:
        os.replace(staged, target)
    except BaseException:
        if had_target:
            os.replace(backup, target)
        raise
    if had_target:
        shutil.rmtree(backup)


def _qa_names(pet_id: str) -> tuple[str, str]:
    if pet_id == "choco":
        return "report.json", "contact-sheet.png"
    return f"{pet_id}-report.json", f"{pet_id}-contact-sheet.png"


def build(args: argparse.Namespace) -> None:
    pet_id = args.pet_id or args.base.parent.name
    rig_path = args.rig or args.base.with_name("rig.json")
    args.output_dir.parent.mkdir(parents=True, exist_ok=True)
    args.qa_dir.mkdir(parents=True, exist_ok=True)
    report_name, contact_name = _qa_names(pet_id)
    preserve_existing = set(args.preserve_existing)

    with tempfile.TemporaryDirectory(
        prefix=f".{args.output_dir.name}.build-", dir=args.output_dir.parent
    ) as asset_temp, tempfile.TemporaryDirectory(
        prefix=f".{pet_id}-qa-build-", dir=args.qa_dir
    ) as qa_temp:
        staged_assets = Path(asset_temp) / "garments"
        staged_qa = Path(qa_temp)
        staged_assets.mkdir()
        base = Image.open(args.base).convert("RGBA")
        base_mask = binary_alpha(base)
        base_pet_pixels = count_mask(base_mask)
        specs = build_specs(base, rig_path)
        report = {
            "version": 2,
            "petId": pet_id,
            "validationOnly": args.validate_only,
            "chroma": "#FF00FF",
            "minimumPostureIouOutsideRoi": MIN_POSTURE_IOU,
            "cleanupChromaTolerance": CHROMA_CLEAR_TOLERANCE,
            "qaChromaTolerance": QA_CHROMA_TOLERANCE,
            "generationPromptRequirements": PROMPT_REQUIREMENTS,
            "garments": [],
        }
        contact_rows = []
        manifest_entries = []
        for garment_id, spec in specs.items():
            output = staged_assets / f"{garment_id}.png"
            canonical_path = args.canonical_garment_dir / f"{garment_id}.png"
            if not canonical_path.is_file():
                raise FileNotFoundError(canonical_path)
            canonical_tone = dominant_lab(
                Image.open(canonical_path).convert("RGBA")
            )
            attempt_errors = []
            accepted = None
            if garment_id in preserve_existing:
                existing = args.output_dir / f"{garment_id}.png"
                if not existing.is_file():
                    raise FileNotFoundError(existing)
                shutil.copy2(existing, output)
                layer = Image.open(output).convert("RGBA")
                if layer.size != base.size:
                    raise ValueError(
                        f"{garment_id}: layer canvas {layer.size} does not "
                        f"match {base.size}"
                    )
                layer_qa = validate_garment_layer(
                    garment_id,
                    layer,
                    base_pet_pixels,
                    spec,
                    canonical_tone,
                )
                visible_chroma = count_mask(
                    ImageChops.multiply(
                        chroma_mask(layer, QA_CHROMA_TOLERANCE),
                        binary_alpha(layer),
                    )
                )
                if visible_chroma:
                    raise ValueError(
                        f"{garment_id}: {visible_chroma} strict-QA chroma "
                        "pixels remain"
                    )
                worn = Image.new("RGBA", base.size, (*CHROMA, 255))
                worn.alpha_composite(base)
                worn.alpha_composite(layer)
                accepted = (
                    worn,
                    layer,
                    0,
                    0,
                    1.0,
                    1.0,
                    0.0,
                    visible_chroma,
                    layer_qa,
                    0,
                )
            candidate_dirs = [args.worn_dir]
            if args.retry_worn_dir is not None:
                candidate_dirs.append(args.retry_worn_dir)
            for attempt_number, candidate_dir in enumerate(candidate_dirs, start=1):
                if garment_id in preserve_existing:
                    break
                source = candidate_dir / f"{garment_id}.png"
                try:
                    if not source.is_file():
                        raise FileNotFoundError(source)
                    worn = Image.open(source).convert("RGBA")
                    if worn.size != base.size:
                        worn = worn.resize(base.size, Image.Resampling.NEAREST)
                    worn = normalize_chroma_background(worn)
                    worn, foreground, dx, dy, alignment_iou = align_to_base(
                        base_mask, worn
                    )
                    posture_iou = posture_iou_outside_roi(
                        base_mask, foreground, spec.roi
                    )
                    if posture_iou < MIN_POSTURE_IOU:
                        raise ValueError(
                            f"{garment_id}: posture IoU outside garment ROI "
                            f"{posture_iou:.4f} "
                            f"is below {MIN_POSTURE_IOU}"
                        )
                    outside_change = outside_roi_change_fraction(
                        base, worn, foreground, spec.roi
                    )
                    if outside_change > MAX_OUTSIDE_ROI_CHANGE:
                        raise ValueError(
                            f"{garment_id}: {outside_change:.2%} high-confidence "
                            "change outside garment ROI"
                        )
                    # imagegen preserves aspect ratio but not the source pixel
                    # dimensions. Nearest-neighbour resize can perturb outline
                    # pixels, so lock the immutable region before extraction.
                    worn = lock_outside_roi(base, worn, spec.roi)
                    foreground = chroma_foreground(worn)
                    layer = extract_layer(base, worn, foreground, spec)
                    layer.save(output, optimize=True)
                    if layer.size != base.size:
                        raise ValueError(
                            f"{garment_id}: layer canvas {layer.size} does not "
                            f"match {base.size}"
                        )
                    layer_qa = validate_garment_layer(
                        garment_id,
                        layer,
                        base_pet_pixels,
                        spec,
                        canonical_tone,
                    )
                    visible_chroma = count_mask(
                        ImageChops.multiply(
                            chroma_mask(layer, QA_CHROMA_TOLERANCE),
                            binary_alpha(layer),
                        )
                    )
                    if visible_chroma:
                        raise ValueError(
                            f"{garment_id}: {visible_chroma} strict-QA chroma "
                            "pixels remain"
                        )
                    accepted = (
                        worn,
                        layer,
                        dx,
                        dy,
                        alignment_iou,
                        posture_iou,
                        outside_change,
                        visible_chroma,
                        layer_qa,
                        attempt_number,
                    )
                    break
                except (FileNotFoundError, ValueError) as error:
                    attempt_errors.append(str(error))
            if accepted is None:
                detail = "; ".join(
                    f"attempt {index}: {message}"
                    for index, message in enumerate(attempt_errors, start=1)
                )
                raise ValueError(
                    f"{garment_id}: all generated candidates failed QA: {detail}"
                )
            (
                worn,
                layer,
                dx,
                dy,
                alignment_iou,
                posture_iou,
                outside_change,
                visible_chroma,
                layer_qa,
                attempt_number,
            ) = accepted
            digest = hashlib.sha256(output.read_bytes()).hexdigest()
            report["garments"].append(
                {
                    "id": garment_id,
                    "anchor": spec.anchor,
                    "alignment": [dx, dy],
                    "alignmentIou": round(alignment_iou, 6),
                    "postureIouOutsideRoi": round(posture_iou, 6),
                    "outsideRoiChangeFraction": round(outside_change, 6),
                    "visibleChromaPixels": visible_chroma,
                    "preservedExisting": garment_id in preserve_existing,
                    "generationAttempts": attempt_number,
                    "rejectedAttempts": attempt_errors,
                    **layer_qa,
                    "sha256": digest,
                }
            )
            manifest_entries.append(
                {
                    "id": garment_id,
                    "anchor": spec.anchor,
                    "asset": f"{garment_id}.png",
                }
            )
            contact_rows.append((garment_id, worn, layer))

        (staged_assets / "garments.json").write_text(
            json.dumps(
                {
                    "formatVersion": 1,
                    "petId": pet_id,
                    "canvas": {"width": base.width, "height": base.height},
                    "garments": manifest_entries,
                },
                indent=2,
            )
            + "\n"
        )
        staged_report = staged_qa / report_name
        staged_contact = staged_qa / contact_name
        staged_report.write_text(json.dumps(report, indent=2) + "\n")
        make_contact_sheet(base, contact_rows, staged_contact)

        if len(report["garments"]) != len(RULES):
            raise ValueError("The garment set is incomplete")
        if any(item["visibleChromaPixels"] for item in report["garments"]):
            raise ValueError("Strict chroma QA failed")
        if not args.validate_only:
            _atomic_replace_directory(staged_assets, args.output_dir)
        os.replace(staged_report, args.qa_dir / report_name)
        os.replace(staged_contact, args.qa_dir / contact_name)


def main() -> None:
    build(parse_args())


if __name__ == "__main__":
    main()

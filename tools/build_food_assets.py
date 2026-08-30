#!/usr/bin/env python3
"""Build and hard-gate the seven SPEC-020 pixel food assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import uuid
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


CHROMA = (255, 0, 255)
CANVAS = (40, 40)
TARGET_INSET = 1
SOURCE_BACKGROUND_NORMALIZE_TOLERANCE = 72
CLEANUP_CHROMA_TOLERANCE = 104
# Independent from cleanup by design: changing cleanup must not silently move QA.
QA_CHROMA_TOLERANCE = 96
DESPILL_CHROMA_TOLERANCE = 160
MINIMUM_COVERAGE = 0.55
MAXIMUM_OPAQUE_COLORS = 16
OUTLINE = (47, 35, 38)  # assets/room palette: #2F2326

# Fifteen subject colours derived from the room furniture palette, with two
# food-specific warm extensions. Chroma is the sixteenth quantizer entry and
# becomes transparency, so each published asset remains at <= 15 opaque colours.
ROOM_WARM_PALETTE = (
    OUTLINE,
    (73, 48, 45),
    (104, 65, 55),
    (143, 71, 82),
    (189, 89, 86),
    (201, 137, 119),
    (185, 133, 92),
    (155, 112, 78),
    (214, 169, 66),
    (231, 184, 92),
    (217, 166, 111),
    (241, 211, 154),
    (246, 228, 196),
    (224, 111, 70),
    (242, 154, 98),
)

FOODS = (
    ("biscuit", "#D9A66F", "round scalloped pet biscuit with paw mark"),
    ("chicken_bites", "#E7B85C", "compact pile of boneless chicken bites"),
    ("salmon", "#F29A62", "thick boneless salmon fillet"),
    ("soft_egg", "#F1D39A", "halved soft-boiled egg with jammy yolk"),
    ("drumstick", "#B9855C", "large roasted chicken drumstick"),
    ("steak", "#BD5956", "thick cooked steak with grill marks"),
    ("shrimp", "#F29A62", "plump cooked shrimp curled into a C"),
)


def parse_args() -> argparse.Namespace:
    repository = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        required=True,
        help="Directory containing one chroma-backed PNG per canonical food id.",
    )
    parser.add_argument(
        "--output-dir", type=Path, default=repository / "assets" / "food"
    )
    parser.add_argument(
        "--qa-dir",
        type=Path,
        default=repository / "artifacts" / "spec-020-food",
    )
    return parser.parse_args()


def _chroma_distance(red: int, green: int, blue: int) -> int:
    return max(255 - red, green, 255 - blue)


def _is_chroma(pixel: tuple[int, int, int, int], tolerance: int) -> bool:
    red, green, blue, alpha = pixel
    return bool(alpha) and _chroma_distance(red, green, blue) <= tolerance


def _normalize_chroma_background(image: Image.Image) -> Image.Image:
    """Flood-fill only edge-connected near-magenta pixels to the exact key."""
    result = image.convert("RGBA")
    pixels = result.load()
    width, height = result.size
    queue: deque[tuple[int, int]] = deque()
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
        if not _is_chroma(
            pixels[x, y], SOURCE_BACKGROUND_NORMALIZE_TOLERANCE
        ):
            continue
        pixels[x, y] = (*CHROMA, 255)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                queue.append((nx, ny))
    return result


def _source_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    mask = Image.new("L", image.size)
    mask.putdata(
        [
            0
            if _is_chroma(pixel, SOURCE_BACKGROUND_NORMALIZE_TOLERANCE)
            or pixel[3] == 0
            else 255
            for pixel in image.get_flattened_data()
        ]
    )
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("source contains no non-chroma subject")
    return bounds


def _nearest_downsample(image: Image.Image) -> Image.Image:
    """Crop to the generated subject, then fit it on the uniform 40px grid."""
    crop = image.crop(_source_bounds(image))
    available_width = CANVAS[0] - TARGET_INSET * 2
    available_height = CANVAS[1] - TARGET_INSET * 2
    scale = min(available_width / crop.width, available_height / crop.height)
    size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    reduced = crop.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", CANVAS, (*CHROMA, 255))
    canvas.paste(
        reduced,
        ((CANVAS[0] - size[0]) // 2, (CANVAS[1] - size[1]) // 2),
    )
    return canvas


def _fixed_palette_image() -> Image.Image:
    palette_image = Image.new("P", (1, 1))
    colours = (CHROMA, *ROOM_WARM_PALETTE)
    raw = [channel for colour in colours for channel in colour]
    raw.extend(list(OUTLINE) * (256 - len(colours)))
    palette_image.putpalette(raw)
    return palette_image


def _quantize(image: Image.Image) -> Image.Image:
    return image.convert("RGB").quantize(
        palette=_fixed_palette_image(), dither=Image.Dither.NONE
    ).convert("RGBA")


def _binary_alpha(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(lambda value: 255 if value > 128 else 0)


def _despill(layer: Image.Image) -> Image.Image:
    alpha = _binary_alpha(layer)
    pixels = layer.load()
    alpha_pixels = alpha.load()
    suspicious: list[tuple[int, int]] = []
    for y in range(layer.height):
        for x in range(layer.width):
            if alpha_pixels[x, y] and _is_chroma(
                pixels[x, y], DESPILL_CHROMA_TOLERANCE
            ):
                suspicious.append((x, y))
    for x, y in suspicious:
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
                candidate = pixels[nx, ny]
                if alpha_pixels[nx, ny] and not _is_chroma(
                    candidate, DESPILL_CHROMA_TOLERANCE
                ):
                    replacement = (*candidate[:3], 255)
                    break
            if replacement is not None:
                break
        pixels[x, y] = replacement or (0, 0, 0, 0)
    return layer


def _clean_chroma(image: Image.Image) -> Image.Image:
    layer = image.copy()
    pixels = layer.load()
    for y in range(layer.height):
        for x in range(layer.width):
            pixel = pixels[x, y]
            if pixel[3] == 0 or _is_chroma(pixel, CLEANUP_CHROMA_TOLERANCE):
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (*pixel[:3], 255)
    layer = _despill(layer)
    for y in range(layer.height):
        for x in range(layer.width):
            if layer.getpixel((x, y))[3] == 0:
                layer.putpixel((x, y), (0, 0, 0, 0))
    return layer


def _enforce_one_pixel_outline(layer: Image.Image) -> Image.Image:
    alpha = _binary_alpha(layer)
    eroded = alpha.filter(ImageFilter.MinFilter(3))
    edge = ImageChops.subtract(alpha, eroded)
    pixels = layer.load()
    edge_pixels = edge.load()
    for y in range(layer.height):
        for x in range(layer.width):
            if edge_pixels[x, y]:
                pixels[x, y] = (*OUTLINE, 255)
    return layer


def _opaque_colours(image: Image.Image) -> set[tuple[int, int, int]]:
    return {
        (red, green, blue)
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha
    }


def _validate(food_id: str, image: Image.Image) -> dict[str, object]:
    if image.size != CANVAS:
        raise ValueError(f"{food_id}: size {image.size} != {CANVAS}")
    if image.mode != "RGBA":
        raise ValueError(f"{food_id}: mode {image.mode} is not RGBA")
    alpha_values = set(image.getchannel("A").get_flattened_data())
    if not alpha_values <= {0, 255} or 0 not in alpha_values or 255 not in alpha_values:
        raise ValueError(f"{food_id}: alpha must contain binary transparency")
    transparent_rgb_residue = sum(
        1
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha == 0 and (red or green or blue)
    )
    if transparent_rgb_residue:
        raise ValueError(
            f"{food_id}: {transparent_rgb_residue} transparent RGB residues"
        )
    opaque_pixels = sum(1 for pixel in image.get_flattened_data() if pixel[3])
    coverage = opaque_pixels / (CANVAS[0] * CANVAS[1])
    if coverage < MINIMUM_COVERAGE:
        raise ValueError(
            f"{food_id}: coverage {coverage:.2%} is below {MINIMUM_COVERAGE:.2%}"
        )
    colours = _opaque_colours(image)
    if len(colours) > MAXIMUM_OPAQUE_COLORS:
        raise ValueError(
            f"{food_id}: {len(colours)} opaque colours exceed {MAXIMUM_OPAQUE_COLORS}"
        )
    unexpected = colours - set(ROOM_WARM_PALETTE)
    if unexpected:
        raise ValueError(f"{food_id}: colours outside room-warm-v1: {unexpected}")
    visible_chroma = sum(
        1
        for pixel in image.get_flattened_data()
        if _is_chroma(pixel, QA_CHROMA_TOLERANCE)
    )
    if visible_chroma:
        raise ValueError(
            f"{food_id}: {visible_chroma} opaque chroma pixels remain at QA threshold"
        )
    alpha = _binary_alpha(image)
    edge = ImageChops.subtract(alpha, alpha.filter(ImageFilter.MinFilter(3)))
    edge_count = sum(1 for value in edge.get_flattened_data() if value)
    outlined = sum(
        1
        for pixel, edge_value in zip(
            image.get_flattened_data(), edge.get_flattened_data()
        )
        if edge_value and pixel[:3] == OUTLINE
    )
    if not edge_count or outlined != edge_count:
        raise ValueError(f"{food_id}: outer contour is not a complete 1px outline")
    border_alpha = sum(
        image.getpixel((x, y))[3] > 0
        for x in range(image.width)
        for y in range(image.height)
        if x in (0, image.width - 1) or y in (0, image.height - 1)
    )
    if border_alpha:
        raise ValueError(f"{food_id}: subject touches the canvas edge")
    return {
        "id": food_id,
        "size": list(image.size),
        "mode": image.mode,
        "opaquePixels": opaque_pixels,
        "coverageFraction": round(coverage, 6),
        "minimumCoverageFraction": MINIMUM_COVERAGE,
        "opaqueColorCount": len(colours),
        "maximumOpaqueColors": MAXIMUM_OPAQUE_COLORS,
        "paletteFamily": "room-warm-v1",
        "paletteFamilyPassed": True,
        "outlinePixels": edge_count,
        "outlineCoverageFraction": round(outlined / edge_count, 6),
        "onePixelDarkOutlinePassed": True,
        "alphaValues": sorted(alpha_values),
        "transparentRgbResiduePixels": transparent_rgb_residue,
        "visibleChromaPixels": visible_chroma,
        "canvasBorderOpaquePixels": border_alpha,
    }


def _checkerboard(size: tuple[int, int], cell: int = 10) -> Image.Image:
    background = Image.new("RGBA", size, "#F6E4C4")
    draw = ImageDraw.Draw(background)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill="#D9D0C4")
    return background


def _make_contact_sheet(
    images: list[tuple[str, Image.Image]], output: Path
) -> None:
    columns, tile_width, tile_height = 4, 180, 210
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * tile_width, rows * tile_height), "#2F2326")
    draw = ImageDraw.Draw(sheet)
    for index, (food_id, sprite) in enumerate(images):
        column, row = index % columns, index // columns
        x, y = column * tile_width, row * tile_height
        preview = _checkerboard((160, 160))
        preview.alpha_composite(sprite.resize((160, 160), Image.Resampling.NEAREST))
        sheet.paste(preview.convert("RGB"), (x + 10, y + 10))
        draw.text((x + 10, y + 180), food_id, fill="#F6E4C4")
        draw.text((x + 10, y + 194), "40x40 / room-warm-v1", fill="#D9A66F")
    sheet.save(output, optimize=True)


def _atomic_replace_directories(
    replacements: list[tuple[Path, Path]],
) -> None:
    backups: dict[Path, Path] = {}
    installed: list[Path] = []
    try:
        for _staged, target in replacements:
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                backup = target.parent / f".{target.name}.backup-{uuid.uuid4().hex}"
                os.replace(target, backup)
                backups[target] = backup
        for staged, target in replacements:
            os.replace(staged, target)
            installed.append(target)
    except BaseException:
        for target in reversed(installed):
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()
        for target, backup in backups.items():
            if backup.exists():
                os.replace(backup, target)
        raise
    for backup in backups.values():
        if backup.is_dir():
            shutil.rmtree(backup)
        elif backup.exists():
            backup.unlink()


def build(args: argparse.Namespace) -> None:
    source_dir = args.source_dir.resolve()
    output_dir = args.output_dir.resolve()
    qa_dir = args.qa_dir.resolve()
    missing = [food_id for food_id, _placeholder, _prompt in FOODS if not (source_dir / f"{food_id}.png").is_file()]
    if missing:
        raise FileNotFoundError(f"missing canonical source PNGs: {', '.join(missing)}")

    output_dir.parent.mkdir(parents=True, exist_ok=True)
    qa_dir.parent.mkdir(parents=True, exist_ok=True)
    staged_output = Path(
        tempfile.mkdtemp(prefix=f".{output_dir.name}.build-", dir=output_dir.parent)
    )
    staged_qa = Path(
        tempfile.mkdtemp(prefix=f".{qa_dir.name}.build-", dir=qa_dir.parent)
    )
    try:
        report_items: list[dict[str, object]] = []
        contact_images: list[tuple[str, Image.Image]] = []
        manifest_entries: list[dict[str, object]] = []
        for food_id, placeholder, _prompt in FOODS:
            source_path = source_dir / f"{food_id}.png"
            source = _normalize_chroma_background(Image.open(source_path))
            reduced = _nearest_downsample(source)
            quantized = _quantize(reduced)
            cleaned = _clean_chroma(quantized)
            published = _enforce_one_pixel_outline(cleaned)
            output_path = staged_output / f"{food_id}.png"
            published.save(output_path, optimize=True)
            item_report = _validate(food_id, Image.open(output_path).convert("RGBA"))
            item_report["sourceSha256"] = hashlib.sha256(source_path.read_bytes()).hexdigest()
            item_report["sha256"] = hashlib.sha256(output_path.read_bytes()).hexdigest()
            report_items.append(item_report)
            contact_images.append((food_id, published))
            manifest_entries.append(
                {
                    "id": food_id,
                    "asset": f"assets/food/{food_id}.png",
                    "pixel_width": CANVAS[0],
                    "pixel_height": CANVAS[1],
                    "placeholder": placeholder,
                }
            )

        (staged_output / "manifest.json").write_text(
            json.dumps(
                {"schema_version": 1, "food": manifest_entries},
                ensure_ascii=False,
                indent=2,
            )
            + "\n"
        )
        report = {
            "schemaVersion": 1,
            "spec": "SPEC-020",
            "passed": True,
            "foodCount": len(report_items),
            "canvas": {"pixelWidth": CANVAS[0], "pixelHeight": CANVAS[1]},
            "thresholds": {
                "sourceBackgroundNormalizeChromaTolerance": SOURCE_BACKGROUND_NORMALIZE_TOLERANCE,
                "cleanupChromaTolerance": CLEANUP_CHROMA_TOLERANCE,
                "qaChromaTolerance": QA_CHROMA_TOLERANCE,
                "despillChromaTolerance": DESPILL_CHROMA_TOLERANCE,
                "minimumCoverageFraction": MINIMUM_COVERAGE,
                "maximumOpaqueColorsPerAsset": MAXIMUM_OPAQUE_COLORS,
            },
            "pipeline": [
                "built-in ImageGen on #FF00FF chroma",
                "nearest-neighbour downsample to 40x40",
                "fixed room-warm-v1 palette quantization",
                "chroma to transparency",
                "edge despill and transparent-RGB zeroing",
                "one-pixel #2F2326 outline enforcement",
                "independent hard-gate QA",
            ],
            "paletteFamily": {
                "id": "room-warm-v1",
                "source": "assets/room furniture palette at commit 1b12b15",
                "outline": "#2F2326",
                "colours": [f"#{r:02X}{g:02X}{b:02X}" for r, g, b in ROOM_WARM_PALETTE],
            },
            "generation": {
                "mode": "built-in image_gen",
                "backdrop": "#FF00FF",
                "sharedStyle": "cozy chunky 16-bit pixel art, warm room-furniture palette family, upper-left highlight, dark warm-brown outline",
                "subjects": {food_id: prompt for food_id, _placeholder, prompt in FOODS},
            },
            "foods": report_items,
        }
        (staged_qa / "report.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        )
        _make_contact_sheet(contact_images, staged_qa / "contact-sheet.png")
        if len(report_items) != len(FOODS):
            raise ValueError("food set is incomplete")
        _atomic_replace_directories(
            [(staged_output, output_dir), (staged_qa, qa_dir)]
        )
    finally:
        if staged_output.exists():
            shutil.rmtree(staged_output)
        if staged_qa.exists():
            shutil.rmtree(staged_qa)


def main() -> None:
    build(parse_args())


if __name__ == "__main__":
    main()

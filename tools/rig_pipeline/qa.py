"""Deterministic image checks, best-of scoring, and QA contact sheets."""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

from .constants import CANONICAL_IMAGE_NAMES


def transparency_ratio(image: Image.Image) -> float:
    alpha = image.convert("RGBA").getchannel("A")
    histogram = alpha.histogram()
    transparent = sum(histogram[:128])
    return transparent / (image.width * image.height)


def validate_canonical_image(image: Image.Image, name: str) -> None:
    if image.mode != "RGBA":
        raise ValueError(f"{name} must be RGBA")
    ratio = transparency_ratio(image)
    if not 0.01 <= ratio <= 0.95:
        raise ValueError(f"{name} transparency ratio {ratio:.3f} is not reasonable")
    if image.getchannel("A").getbbox() is None:
        raise ValueError(f"{name} contains no visible subject")


def silhouette_iou(image: Image.Image, reference: Image.Image) -> float:
    """Alpha-mask IoU between a candidate and a reference silhouette."""

    candidate_alpha = image.convert("RGBA").getchannel("A")
    reference_alpha = reference.convert("RGBA").getchannel("A")
    if candidate_alpha.size != reference_alpha.size:
        candidate_alpha = candidate_alpha.resize(reference_alpha.size, Image.Resampling.NEAREST)
    candidate_mask = candidate_alpha.point(lambda value: 255 if value >= 128 else 0)
    reference_mask = reference_alpha.point(lambda value: 255 if value >= 128 else 0)
    intersection = 0
    union = 0
    for candidate, reference_value in zip(candidate_mask.getdata(), reference_mask.getdata()):
        intersection += bool(candidate and reference_value)
        union += bool(candidate or reference_value)
    return intersection / union if union else 0.0


def candidate_score(image: Image.Image, *, silhouette_reference: Image.Image | None = None) -> float:
    """Prefer a centred, unclipped subject and optionally a matching silhouette."""

    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return float("-inf")
    width, height = rgba.size
    x0, y0, x1, y1 = bbox
    foreground = 1 - transparency_ratio(rgba)
    size_score = 1 - min(abs(foreground - 0.40) / 0.40, 1)
    centre_x = (x0 + x1) / 2 / width
    centre_y = (y0 + y1) / 2 / height
    centre_score = 1 - min(abs(centre_x - 0.5) + abs(centre_y - 0.52), 1)
    clipped_edges = sum((x0 == 0, y0 == 0, x1 == width, y1 == height))
    score = size_score * 2 + centre_score - clipped_edges
    if silhouette_reference is not None:
        score += 4 * silhouette_iou(rgba, silhouette_reference)
    return score


def ground_y(image: Image.Image) -> int:
    bbox = image.convert("RGBA").getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("cannot derive groundY from an empty image")
    return bbox[3] - 1


def _checkerboard(size: tuple[int, int], cell: int = 12) -> Image.Image:
    background = Image.new("RGBA", size, (245, 239, 226, 255))
    draw = ImageDraw.Draw(background)
    alternate = (225, 216, 200, 255)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, min(x + cell - 1, size[0] - 1), min(y + cell - 1, size[1] - 1)), fill=alternate)
    return background


def _overlay_boxes(image: Image.Image, boxes: Mapping[str, list[int | float]] | None) -> Image.Image:
    rendered = image.copy()
    if not boxes:
        return rendered
    draw = ImageDraw.Draw(rendered)
    colours = ((226, 68, 92, 255), (35, 160, 120, 255), (55, 106, 220, 255), (231, 150, 40, 255))
    font = ImageFont.load_default()
    for (label, box), colour in zip(boxes.items(), colours):
        draw.rectangle(tuple(box), outline=colour, width=max(1, image.width // 256))
        draw.text((box[0] + 2, box[1] + 2), label, font=font, fill=colour, stroke_width=1, stroke_fill=(255, 255, 255, 220))
    return rendered


def create_contact_sheet(
    images: Mapping[str, str | Path],
    rig: Mapping[str, Any],
    output: str | Path,
) -> Path:
    """Render four canonical images with front/side box overlays."""

    names = CANONICAL_IMAGE_NAMES
    loaded = {name: Image.open(images[name]).convert("RGBA") for name in names}
    max_width = max(image.width for image in loaded.values())
    max_height = max(image.height for image in loaded.values())
    scale = min(1.0, 560 / max_width, 560 / max_height)
    cell_width = max(180, round(max_width * scale))
    cell_height = max(180, round(max_height * scale))
    label_height = 28
    sheet = Image.new("RGBA", (cell_width * 2, (cell_height + label_height) * 2), (250, 246, 236, 255))

    for index, name in enumerate(names):
        image = loaded[name]
        boxes = None
        if name.startswith("front-"):
            boxes = rig["front"]["boxes"]
        elif name == "side.png":
            boxes = rig["side"]["boxes"]
        rendered = _overlay_boxes(image, boxes)
        target = rendered.resize((round(rendered.width * scale), round(rendered.height * scale)), Image.Resampling.NEAREST)
        background = _checkerboard((cell_width, cell_height))
        background.alpha_composite(target, ((cell_width - target.width) // 2, (cell_height - target.height) // 2))
        column, row = index % 2, index // 2
        x, y = column * cell_width, row * (cell_height + label_height)
        sheet.alpha_composite(background, (x, y + label_height))
        ImageDraw.Draw(sheet).text((x + 8, y + 7), name, fill=(48, 43, 37, 255), font=ImageFont.load_default())

    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output_path, format="PNG")
    for image in loaded.values():
        image.close()
    return output_path

"""Post-generation canonical image normalisation.

Two defects escaped the original preset batch (walkthrough 2026-08-30):

1. A 1–2 px halo of leftover background colour hugs the silhouette because the
   flood fill in :mod:`background` stops at mixed edge pixels.
2. The generated 1408x768 landscape canvases leave the subject a far smaller
   fraction of the canvas than Choco's 1024x1024 reference, so the fit-to-box
   renderer draws every newer pet visibly smaller than Choco.

This module fixes both on an existing unpacked pack directory: it strips the
background halo from every canonical image, then re-frames front-open,
front-closed, and sleep onto Choco-reference canvases and applies the same
affine to the rig's front section. The side canvas is left untouched — the
192x208 display box cannot hold a side pose at front-pose body scale, so its
original framing already is the correct one.

Usage: python3 -m tools.rig_pipeline.normalize assets/pets/blackcat [more...]
"""

from __future__ import annotations

import json
import sys
from math import sqrt
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageFilter

# Choco (the reference pet) framing, measured from its shipped canonicals:
# front content fits an 830x830 box on a 1024x1024 canvas with its feet on
# y=932; sleep content fits 1081x552 on 1408x768 with its body on y=681.
FRONT_CANVAS = (1024, 1024)
FRONT_CONTENT_BOX = (830, 830)
FRONT_BASELINE = 932
SLEEP_CANVAS = (1408, 768)
SLEEP_CONTENT_BOX = (1081, 552)
SLEEP_BASELINE = 681

_OPAQUE_THRESHOLD = 128
_MAX_HALO_RINGS = 3


def _distance(left: tuple[int, ...], right: tuple[int, ...]) -> float:
    return sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def _background_colour(image: Image.Image) -> tuple[int, int, int]:
    """The flood fill keeps RGB under the transparent pixels — read a corner."""

    pixel = image.getpixel((0, 0))
    if pixel[3] >= _OPAQUE_THRESHOLD:
        raise ValueError("top-left corner is opaque; not a background-removed canonical")
    return pixel[:3]


def strip_background_halo(image: Image.Image) -> Image.Image:
    """Erase boundary pixels that are closer to the background colour than to
    the body colour just inside them.

    Intentional dark pixel-art outlines survive: an outline pixel's inward
    neighbour is more outline, so it is never closer to the background.
    """

    result = image.convert("RGBA")
    background = _background_colour(result)
    pixels = result.load()

    for _ in range(_MAX_HALO_RINGS):
        mask = result.getchannel("A").point(lambda a: 255 if a >= _OPAQUE_THRESHOLD else 0)
        boundary = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))
        # The body reference must sit beneath the halo, which can be 2 px deep
        # with both rings halo-coloured — sample from the twice-eroded core so
        # a halo pixel is never judged against its halo neighbour.
        core = mask.filter(ImageFilter.MinFilter(5))
        box = boundary.getbbox()
        if box is None:
            break
        boundary_pixels = boundary.load()
        core_pixels = core.load()
        stripped = []
        for y in range(box[1], box[3]):
            for x in range(box[0], box[2]):
                if not boundary_pixels[x, y]:
                    continue
                neighbours = [
                    pixels[nx, ny][:3]
                    for ny in range(max(0, y - 2), min(result.height, y + 3))
                    for nx in range(max(0, x - 2), min(result.width, x + 3))
                    if core_pixels[nx, ny]
                ]
                if not neighbours:
                    continue  # thin feature (whisker, ear tip); never strip those
                inward = tuple(sum(channel) // len(neighbours) for channel in zip(*neighbours))
                colour = pixels[x, y][:3]
                # The 1.5 margin also catches mixture pixels leaning body-ward,
                # which otherwise survive as sparse fringe on dark backdrops.
                if _distance(colour, background) < 1.5 * _distance(colour, inward):
                    stripped.append((x, y))
        if not stripped:
            break
        for x, y in stripped:
            pixels[x, y] = (*pixels[x, y][:3], 0)
    return result


def _reframe(
    images: list[Image.Image],
    canvas: tuple[int, int],
    content_box: tuple[int, int],
    baseline: int,
) -> tuple[list[Image.Image], tuple[float, int, int, int, int]]:
    """Scale the union content of *images* into *content_box*, bottom-anchored
    at *baseline* and horizontally centred on *canvas*.

    Returns the new images plus the affine (scale, bx0, by0, ox, oy) mapping an
    old coordinate p to round((p - b0) * scale + o).
    """

    boxes = [image.getchannel("A").getbbox() for image in images]
    if any(box is None for box in boxes):
        raise ValueError("cannot reframe an empty image")
    bx0 = min(box[0] for box in boxes)
    by0 = min(box[1] for box in boxes)
    bx1 = max(box[2] for box in boxes)
    by1 = max(box[3] for box in boxes)
    content_width = bx1 - bx0
    content_height = by1 - by0
    scale = min(content_box[0] / content_width, content_box[1] / content_height)
    new_width = round(content_width * scale)
    new_height = round(content_height * scale)
    ox = (canvas[0] - new_width) // 2
    oy = baseline - new_height

    reframed = []
    for image in images:
        # NEAREST keeps the hard stair-stepped pixel edges the style demands.
        content = image.crop((bx0, by0, bx1, by1)).resize((new_width, new_height), Image.Resampling.NEAREST)
        page = Image.new("RGBA", canvas, (0, 0, 0, 0))
        page.paste(content, (ox, oy))
        reframed.append(page)
    return reframed, (scale, bx0, by0, ox, oy)


def _map_point(x: float, y: float, affine: tuple[float, int, int, int, int], canvas: tuple[int, int]) -> list[int]:
    scale, bx0, by0, ox, oy = affine
    return [
        min(canvas[0], max(0, round((x - bx0) * scale + ox))),
        min(canvas[1], max(0, round((y - by0) * scale + oy))),
    ]


def _transform_front_rig(front: dict[str, Any], affine: tuple[float, int, int, int, int]) -> dict[str, Any]:
    transformed: dict[str, Any] = dict(front)
    transformed["groundY"] = _map_point(0, front["groundY"], affine, FRONT_CANVAS)[1]
    transformed["boxes"] = {
        name: _map_point(box[0], box[1], affine, FRONT_CANVAS) + _map_point(box[2], box[3], affine, FRONT_CANVAS)
        for name, box in front["boxes"].items()
    }
    transformed["pivots"] = {
        name: _map_point(pivot[0], pivot[1], affine, FRONT_CANVAS)
        for name, pivot in front["pivots"].items()
    }
    return transformed


def normalize_pack_dir(directory: str | Path) -> None:
    """Normalise an unpacked rig pack v3 directory in place."""

    directory = Path(directory)
    rig_path = directory / "rig.json"
    rig = json.loads(rig_path.read_text())

    loaded = {
        name: strip_background_halo(Image.open(directory / f"{name}.png"))
        for name in ("front-open", "front-closed", "sleep", "side")
        if (directory / f"{name}.png").exists()
    }

    fronts, affine = _reframe(
        [loaded["front-open"], loaded["front-closed"]], FRONT_CANVAS, FRONT_CONTENT_BOX, FRONT_BASELINE
    )
    loaded["front-open"], loaded["front-closed"] = fronts
    rig["front"] = _transform_front_rig(rig["front"], affine)

    (loaded["sleep"],), _ = _reframe([loaded["sleep"]], SLEEP_CANVAS, SLEEP_CONTENT_BOX, SLEEP_BASELINE)

    for name, image in loaded.items():
        image.save(directory / f"{name}.png", format="PNG")
    rig_path.write_text(json.dumps(rig, separators=(",", ":")))


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: python3 -m tools.rig_pipeline.normalize <pack-dir> [more...]", file=sys.stderr)
        return 2
    for directory in argv:
        normalize_pack_dir(directory)
        print(f"normalized {directory}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

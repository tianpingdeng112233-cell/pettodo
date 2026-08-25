"""Construction and validation of rig.json."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from numbers import Real
from typing import Any


FRONT_PARTS = ("head", "tail", "leftFrontLeg", "rightFrontLeg")
SIDE_PARTS = ("head", "tail", "frontLeg", "hindLeg")


def _clean_number(value: Real) -> int | float:
    value = float(value)
    return int(value) if value.is_integer() else value


def _validate_boxes(
    boxes: Mapping[str, Sequence[Real]],
    required_parts: tuple[str, ...],
    size: tuple[int, int],
    view: str,
) -> dict[str, list[int | float]]:
    if set(boxes) != set(required_parts):
        raise ValueError(f"{view} boxes must contain exactly: {', '.join(required_parts)}")
    width, height = size
    cleaned: dict[str, list[int | float]] = {}
    for part in required_parts:
        box = boxes[part]
        if not isinstance(box, Sequence) or isinstance(box, (str, bytes)) or len(box) != 4:
            raise ValueError(f"{view}.{part} must be [x0, y0, x1, y1]")
        if any(isinstance(value, bool) or not isinstance(value, Real) for value in box):
            raise ValueError(f"{view}.{part} coordinates must be numbers")
        x0, y0, x1, y1 = (float(value) for value in box)
        if not (0 <= x0 < x1 <= width and 0 <= y0 < y1 <= height):
            raise ValueError(f"{view}.{part} box must be within image bounds {width}x{height}")
        cleaned[part] = [_clean_number(value) for value in (x0, y0, x1, y1)]
    return cleaned


def _midpoint(first: Real, second: Real) -> int | float:
    return _clean_number((float(first) + float(second)) / 2)


def _tail_pivot(box: Sequence[Real], body_centre_x: float) -> list[int | float]:
    # The tail attaches on whichever tail-box edge is closer to the body mass.
    # Reference is the head-box centre, not the canvas centre — an off-centre
    # sprite must not flip the pivot side.
    x0, y0, x1, y1 = box
    body_side_x = x0 if abs(float(x0) - body_centre_x) < abs(float(x1) - body_centre_x) else x1
    return [_clean_number(body_side_x), _midpoint(y0, y1)]


def _box_centre_x(box: Sequence[Real]) -> float:
    return (float(box[0]) + float(box[2])) / 2


def _bottom_centre(box: Sequence[Real]) -> list[int | float]:
    x0, _, x1, y1 = box
    return [_midpoint(x0, x1), _clean_number(y1)]


def _top_centre(box: Sequence[Real]) -> list[int | float]:
    x0, y0, x1, _ = box
    return [_midpoint(x0, x1), _clean_number(y0)]


def build_rig(
    *,
    front_boxes: Mapping[str, Sequence[Real]],
    side_boxes: Mapping[str, Sequence[Real]],
    front_size: tuple[int, int],
    side_size: tuple[int, int],
    front_ground_y: Real,
    side_ground_y: Real,
    side_facing: str = "right",
) -> dict[str, Any]:
    """Build the exact rigVersion 1 shape and derive all pivots geometrically."""

    if side_facing != "right":
        raise ValueError("rig pack v3 side view must face right")
    front = _validate_boxes(front_boxes, FRONT_PARTS, front_size, "front")
    side = _validate_boxes(side_boxes, SIDE_PARTS, side_size, "side")
    for label, value, height in (
        ("front groundY", front_ground_y, front_size[1]),
        ("side groundY", side_ground_y, side_size[1]),
    ):
        if isinstance(value, bool) or not isinstance(value, Real) or not 0 <= value < height:
            raise ValueError(f"{label} must be within image bounds")

    return {
        "rigVersion": 1,
        "front": {
            "groundY": _clean_number(front_ground_y),
            "boxes": front,
            "pivots": {
                "head": _bottom_centre(front["head"]),
                "tail": _tail_pivot(front["tail"], _box_centre_x(front["head"])),
            },
        },
        "side": {
            "groundY": _clean_number(side_ground_y),
            "facing": side_facing,
            "boxes": side,
            "pivots": {
                "head": _bottom_centre(side["head"]),
                "tail": _tail_pivot(side["tail"], _box_centre_x(side["head"])),
                "frontLeg": _top_centre(side["frontLeg"]),
                "hindLeg": _top_centre(side["hindLeg"]),
            },
        },
    }


def validate_rig(rig: Mapping[str, Any], image_sizes: Mapping[str, tuple[int, int]]) -> None:
    """Validate a rig mapping against the two source image dimensions."""

    if type(rig.get("rigVersion")) is not int or rig["rigVersion"] != 1:
        raise ValueError("rig.json rigVersion must be the integer 1")
    if not isinstance(rig.get("front"), Mapping) or not isinstance(rig.get("side"), Mapping):
        raise ValueError("rig.json must contain front and side objects")
    if set(rig) != {"rigVersion", "front", "side"}:
        raise ValueError("rig.json must contain exactly rigVersion, front, side")
    if set(rig["front"]) != {"groundY", "boxes", "pivots"}:
        raise ValueError("rig.json front must contain exactly groundY, boxes, pivots")
    if set(rig["side"]) != {"groundY", "facing", "boxes", "pivots"}:
        raise ValueError("rig.json side must contain exactly groundY, facing, boxes, pivots")
    rebuilt = build_rig(
        front_boxes=rig["front"].get("boxes", {}),
        side_boxes=rig["side"].get("boxes", {}),
        front_size=image_sizes["front"],
        side_size=image_sizes["side"],
        front_ground_y=rig["front"].get("groundY"),
        side_ground_y=rig["side"].get("groundY"),
        side_facing=rig["side"].get("facing"),
    )
    if rig.get("front", {}).get("pivots") != rebuilt["front"]["pivots"]:
        raise ValueError("front pivots do not match contract geometry")
    if rig.get("side", {}).get("pivots") != rebuilt["side"]["pivots"]:
        raise ValueError("side pivots do not match contract geometry")

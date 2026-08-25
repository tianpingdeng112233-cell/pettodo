"""Background removal for canonical pose images."""

from __future__ import annotations

from collections import deque
from math import sqrt

from PIL import Image


def _distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    return sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def remove_solid_background(image: Image.Image, threshold: float = 36) -> Image.Image:
    """Make corner-connected, near-solid background pixels transparent.

    Each corner is its own flood-fill seed so a slightly different flat colour at
    another corner is still removed. Enclosed areas remain opaque by design.
    """

    if threshold < 0:
        raise ValueError("background threshold must be non-negative")

    result = image.convert("RGBA")
    width, height = result.size
    if width == 0 or height == 0:
        raise ValueError("image must not be empty")

    pixels = result.load()
    corners = ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))
    visited: set[tuple[int, int]] = set()

    for seed in corners:
        if seed in visited:
            continue
        seed_colour = pixels[seed][:3]
        queue = deque([seed])
        while queue:
            x, y = queue.popleft()
            if (x, y) in visited:
                continue
            if _distance(pixels[x, y][:3], seed_colour) > threshold:
                continue
            visited.add((x, y))
            pixels[x, y] = (*pixels[x, y][:3], 0)
            if x:
                queue.append((x - 1, y))
            if x + 1 < width:
                queue.append((x + 1, y))
            if y:
                queue.append((x, y - 1))
            if y + 1 < height:
                queue.append((x, y + 1))

    return result

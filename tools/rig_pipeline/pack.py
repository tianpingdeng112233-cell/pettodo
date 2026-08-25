"""Flat rig pack v3 archive writer."""

from __future__ import annotations

import json
import re
import zipfile
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from PIL import Image

from .constants import CANONICAL_IMAGE_NAMES
from .qa import validate_canonical_image
from .rig import validate_rig


_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def validate_pack_metadata(pack: Mapping[str, Any]) -> None:
    required = {"formatVersion", "id", "display_name", "species", "treat"}
    if set(pack) != required:
        raise ValueError("pack.json must contain the exact rig pack v3 fields")
    if type(pack.get("formatVersion")) is not int or pack["formatVersion"] != 3:
        raise ValueError("pack.json formatVersion must be the integer 3")
    if not isinstance(pack["id"], str) or not _SLUG.fullmatch(pack["id"]):
        raise ValueError("pack.json id must be a lowercase hyphenated slug")
    if not isinstance(pack["display_name"], str) or not pack["display_name"].strip():
        raise ValueError("pack.json display_name must be non-empty")
    if pack["species"] not in ("cat", "dog"):
        raise ValueError("pack.json species must be cat or dog")
    treat = pack["treat"]
    if (
        not isinstance(treat, Mapping)
        or set(treat) != {"name", "emoji"}
        or not all(isinstance(treat[key], str) and treat[key] for key in treat)
    ):
        raise ValueError("pack.json treat must contain non-empty name and emoji")


def build_pack(
    output: str | Path,
    *,
    pack: Mapping[str, Any],
    rig: Mapping[str, Any],
    images: Mapping[str, str | Path],
) -> Path:
    """Validate inputs and atomically write a flat .pettodopet zip."""

    validate_pack_metadata(pack)
    if set(images) != set(CANONICAL_IMAGE_NAMES):
        raise ValueError("exactly four canonical images are required")

    image_sizes: dict[str, tuple[int, int]] = {}
    for name in CANONICAL_IMAGE_NAMES:
        path = Path(images[name])
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG" or image.mode != "RGBA":
                raise ValueError(f"{name} must be an RGBA PNG")
            if image.width < 1 or image.height < 1:
                raise ValueError(f"{name} must not be empty")
            # de-backgrounded sprites must actually be transparent around the
            # subject — an opaque canvas violates the v3 contract
            validate_canonical_image(image, name)
            if name == "front-open.png":
                image_sizes["front"] = image.size
            elif name == "side.png":
                image_sizes["side"] = image.size
            elif name == "front-closed.png" and image.size != image_sizes["front"]:
                raise ValueError("front-open.png and front-closed.png must share dimensions")
    validate_rig(rig, image_sizes)

    output_path = Path(output)
    if output_path.suffix != ".pettodopet":
        raise ValueError("output must use the .pettodopet extension")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_name(f".{output_path.name}.tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("pack.json", json.dumps(pack, ensure_ascii=False, separators=(",", ":")))
            archive.writestr("rig.json", json.dumps(rig, ensure_ascii=False, separators=(",", ":")))
            for name in CANONICAL_IMAGE_NAMES:
                archive.write(images[name], arcname=name)
        temporary.replace(output_path)
    finally:
        if temporary.exists():
            temporary.unlink()
    return output_path

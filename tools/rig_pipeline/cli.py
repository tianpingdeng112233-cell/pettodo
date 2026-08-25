"""Command-line interface for the PetTodo rig pipeline."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from .gemini import IMAGE_MODEL, RIG_MODEL
from .pipeline import PipelineConfig, run_pipeline


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python3 -m tools.rig_pipeline",
        description="Turn 1–3 pet photos, or a text-only breed description, into a flat rig pack v3.",
        epilog=(
            "Canonical quality benchmark: ~/Projects/scratch/pet-rig-spike/canon/three-1.png "
            "+ config.json (gemini-3.1-flash-image, three image inputs)."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("photos", nargs="*", help="1–3 JPEG/PNG identity-reference photos")
    parser.add_argument("--text-only", metavar="DESCRIPTION", help="breed/appearance description instead of photos")
    parser.add_argument("--id", dest="pet_id", help="lowercase hyphenated pack slug; derived when omitted")
    parser.add_argument("--name", dest="display_name", help="display name; derived when omitted")
    parser.add_argument("--species", choices=("cat", "dog"), help="override model species classification")
    parser.add_argument("--treat-name", default="treat", help="pack treat name")
    parser.add_argument("--treat-emoji", default="🦴", help="pack treat emoji")
    parser.add_argument("--output", type=Path, help="output .pettodopet path")
    parser.add_argument("--qa-output", type=Path, help="QA contact sheet PNG path")
    parser.add_argument("--best-of", type=int, default=2, help="generated candidates scored per canonical pose")
    parser.add_argument("--retries", type=int, default=3, help="Gemini retries after the initial attempt")
    parser.add_argument("--background-threshold", type=float, default=36, help="RGB Euclidean flood-fill threshold")
    parser.add_argument("--dry-run", action="store_true", help="validate arguments and print the full plan without network or Keychain access")
    return parser


def _error(parser: argparse.ArgumentParser, message: str) -> int:
    print(f"{parser.prog}: error: {message}", file=sys.stderr)
    return 2


def _slug(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "pet"


def _validate_photo(path: Path) -> str | None:
    if path.suffix.lower() not in (".jpg", ".jpeg", ".png"):
        return f"unsupported photo extension: {path}"
    if not path.is_file():
        return f"photo not found: {path}"
    try:
        with Image.open(path) as image:
            image.verify()
    except (OSError, UnidentifiedImageError):
        return f"photo is not a readable JPEG/PNG: {path}"
    return None


def _dry_run(config: PipelineConfig) -> str:
    source = f"text description: {config.text_only}" if config.text_only else f"{len(config.photos)} photo(s): {', '.join(map(str, config.photos))}"
    return f"""Rig pipeline dry run
1. Input: {source}
2. Generate with {IMAGE_MODEL}: {config.best_of} candidates per canonical pose; request order front-open.png -> front-closed.png -> sleep.png -> side.png; retry each request up to {config.retries} time(s).
3. Score candidates for visible, centred, unclipped subjects; choose best; flood-fill the solid background at RGB threshold {config.background_threshold:g}; save RGBA.
4. Detect front/side part boxes with {RIG_MODEL} JSON mode; derive head/tail/leg pivots and groundY in source-PNG pixels.
5. Validate four images, transparency ratios, in-bounds boxes, and rig/pack contract fields; render QA contact sheet with box overlays at {config.qa_output}.
6. Write flat rig pack v3 to {config.output} with pack.json, rig.json, and four canonical PNGs.
Key source for live run: macOS Keychain service gemini-api-key (never written to disk)."""


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as error:
        return int(error.code)

    if not args.photos and not args.text_only:
        return _error(parser, "provide 1–3 photos or --text-only")
    if args.photos and args.text_only:
        return _error(parser, "photos and --text-only cannot be combined")
    if len(args.photos) > 3:
        return _error(parser, "provide at most 3 photos")
    if args.text_only is not None and not args.text_only.strip():
        return _error(parser, "--text-only description must be non-empty")
    if args.best_of < 1:
        return _error(parser, "--best-of must be at least 1")
    if args.retries < 0:
        return _error(parser, "--retries must be non-negative")
    if args.background_threshold < 0:
        return _error(parser, "--background-threshold must be non-negative")

    photos = tuple(Path(value).expanduser().resolve() for value in args.photos)
    for photo in photos:
        problem = _validate_photo(photo)
        if problem:
            return _error(parser, problem)

    identity = args.display_name or args.pet_id or args.text_only or (photos[0].stem if photos else "pet")
    pet_id = args.pet_id or _slug(identity)
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", pet_id):
        return _error(parser, "--id must be a lowercase hyphenated slug")
    display_name = args.display_name or pet_id.replace("-", " ").title()
    output = (args.output or Path(f"{pet_id}.pettodopet")).expanduser().resolve()
    if output.suffix != ".pettodopet":
        return _error(parser, "--output must use the .pettodopet extension")
    qa_output = (args.qa_output or output.with_suffix(".qa.png")).expanduser().resolve()
    if qa_output.suffix.lower() != ".png":
        return _error(parser, "--qa-output must use the .png extension")

    config = PipelineConfig(
        photos=photos,
        text_only=args.text_only.strip() if args.text_only else None,
        pet_id=pet_id,
        display_name=display_name,
        species=args.species,
        treat_name=args.treat_name,
        treat_emoji=args.treat_emoji,
        output=output,
        qa_output=qa_output,
        best_of=args.best_of,
        background_threshold=args.background_threshold,
        retries=args.retries,
    )
    if args.dry_run:
        print(_dry_run(config))
        return 0
    try:
        output_path, qa_path = run_pipeline(config)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"rig pipeline failed: {error}", file=sys.stderr)
        return 1
    print(f"Created {output_path}")
    print(f"QA contact sheet: {qa_path}")
    return 0

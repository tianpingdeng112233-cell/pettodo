"""End-to-end canonical pose generation and rig pack assembly."""

from __future__ import annotations

import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image

from .background import remove_solid_background
from .constants import CANONICAL_IMAGE_NAMES
from .gemini import GeminiClient, GeminiError, GeminiTransportError, read_api_key
from .pack import build_pack
from .qa import candidate_score, create_contact_sheet, ground_y, silhouette_iou, validate_canonical_image
from .rig import build_rig


POSES = {
    "front-open.png": "front view, sitting upright, eyes open, both front legs visible and separated, tail visible, looking directly at viewer",
    "front-closed.png": "the exact same front sitting pose, framing, silhouette, expression, and limb placement as the supplied front-open canonical image; change only the eyes from open to gently closed",
    "sleep.png": "curled sleeping pose, eyes closed, whole body and tail readable with minimal self-occlusion",
    "side.png": "strict side view standing on all four legs, facing right, head and full tail visible, front and hind legs readable with minimal overlap",
}

# POSES must stay keyed by the canonical archive names
assert tuple(POSES) == CANONICAL_IMAGE_NAMES

STYLE_PROMPT ="""Create exactly one canonical-pose pet sprite on a single flat, high-contrast solid-colour background. The pet must be fully inside the canvas with generous margin and no shadow, floor, props, text, border, or scenery. Pixel game-sprite style: chunky pixel clusters, hard stair-stepped edges, absolutely no antialiasing, restrained warm palette. Preserve the individual pet's identity from the reference photos: coat colours and markings, face shape, ear shape, body proportions, and tail. Do not add accessories."""


@dataclass(frozen=True)
class PipelineConfig:
    photos: tuple[Path, ...]
    text_only: str | None
    pet_id: str
    display_name: str
    species: str | None
    treat_name: str
    treat_emoji: str
    output: Path
    qa_output: Path
    best_of: int = 2
    background_threshold: float = 36
    retries: int = 3
    # front-closed must be the same pose as front-open; below this alpha-mask
    # IoU a candidate is rejected outright (contract: front boxes fit both)
    min_silhouette_iou: float = 0.85


def _identity_prompt(config: PipelineConfig) -> str:
    if config.text_only:
        return f"Identity description (no photo references): {config.text_only.strip()}"
    return "Use all supplied pet photos as identity references; do not copy their pose or background."


def _select_candidate(
    *,
    client: GeminiClient,
    config: PipelineConfig,
    name: str,
    references: list[Path],
    directory: Path,
    silhouette_reference: Path | None = None,
) -> Image.Image:
    prompt = f"{STYLE_PROMPT}\n{_identity_prompt(config)}\nRequired pose: {POSES[name]}"
    if silhouette_reference is not None:
        prompt += "\nThe final supplied image is the selected front-open canonical image; match its silhouette and pixel placement exactly."
    valid: list[tuple[float, Image.Image]] = []
    failures: list[str] = []
    reference_image = Image.open(silhouette_reference).convert("RGBA") if silhouette_reference else None
    for number in range(1, config.best_of + 1):
        try:
            generated = client.generate_image(prompt=prompt, reference_images=references)
        except GeminiTransportError:
            raise  # transport has spent its whole retry budget; do not resample
        except GeminiError as error:
            # one failed candidate must not abort the whole best-of sample
            failures.append(f"{name} candidate {number}: {error}")
            continue
        prepared = remove_solid_background(generated, threshold=config.background_threshold)
        generated.close()
        try:
            validate_canonical_image(prepared, f"{name} candidate {number}")
        except ValueError as error:
            failures.append(str(error))
            prepared.close()
            continue
        if reference_image is not None:
            iou = silhouette_iou(prepared, reference_image)
            if iou < config.min_silhouette_iou:
                failures.append(
                    f"{name} candidate {number}: silhouette IoU {iou:.2f} below {config.min_silhouette_iou}"
                )
                prepared.close()
                continue
        score = candidate_score(prepared, silhouette_reference=reference_image)
        candidate_path = directory / f"{Path(name).stem}.candidate-{number}.png"
        prepared.save(candidate_path, format="PNG")
        valid.append((score, prepared))
    if not valid:
        if reference_image:
            reference_image.close()
        details = "; ".join(failures) or "no image candidates returned"
        raise ValueError(f"all {name} candidates failed QA: {details}")
    valid.sort(key=lambda item: item[0], reverse=True)
    selected = valid[0][1]
    for _, rejected in valid[1:]:
        rejected.close()
    if reference_image:
        reference_image.close()
    return selected


def run_pipeline(
    config: PipelineConfig,
    *,
    client: GeminiClient | None = None,
    progress: Callable[[str], None] = print,
) -> tuple[Path, Path]:
    """Run image generation, de-backgrounding, rig detection, QA, and packing."""

    if client is None:
        client = GeminiClient(read_api_key(), retries=config.retries)

    with tempfile.TemporaryDirectory(prefix="pettodo-rig-") as temporary:
        work = Path(temporary)
        selected_paths: dict[str, Path] = {}
        for name in CANONICAL_IMAGE_NAMES:
            progress(f"Generating {name} ({config.best_of} candidates)...")
            references = list(config.photos)
            if name == "front-closed.png":
                references.append(selected_paths["front-open.png"])
            selected = _select_candidate(
                client=client,
                config=config,
                name=name,
                references=references,
                directory=work,
                silhouette_reference=selected_paths.get("front-open.png") if name == "front-closed.png" else None,
            )
            if name == "front-closed.png":
                with Image.open(selected_paths["front-open.png"]) as front_open:
                    if selected.size != front_open.size:
                        resized = selected.resize(front_open.size, Image.Resampling.NEAREST)
                        selected.close()
                        selected = resized
            output_path = work / name
            selected.save(output_path, format="PNG")
            selected.close()
            selected_paths[name] = output_path

        progress("Detecting front and side part boxes...")
        detected = client.detect_rig(
            front_image=selected_paths["front-open.png"],
            side_image=selected_paths["side.png"],
        )
        try:
            front_boxes = detected["front"]["boxes"]
            side_boxes = detected["side"]["boxes"]
        except (KeyError, TypeError) as error:
            raise ValueError("rig model JSON is missing front/side boxes") from error
        with Image.open(selected_paths["front-open.png"]) as front_image, Image.open(selected_paths["side.png"]) as side_image:
            rig = build_rig(
                front_boxes=front_boxes,
                side_boxes=side_boxes,
                front_size=front_image.size,
                side_size=side_image.size,
                front_ground_y=ground_y(front_image),
                side_ground_y=ground_y(side_image),
                side_facing=detected.get("side", {}).get("facing", "right"),
            )

        species = config.species or detected.get("species")
        if species not in ("cat", "dog"):
            raise ValueError("could not classify the generated pet as cat or dog; pass --species")
        pack = {
            "formatVersion": 3,
            "id": config.pet_id,
            "display_name": config.display_name,
            "species": species,
            "treat": {"name": config.treat_name, "emoji": config.treat_emoji},
        }

        progress("Rendering QA contact sheet with box overlays...")
        create_contact_sheet(selected_paths, rig, config.qa_output)
        progress("Validating and writing flat rig pack v3...")
        build_pack(config.output, pack=pack, rig=rig, images=selected_paths)
    return config.output, config.qa_output

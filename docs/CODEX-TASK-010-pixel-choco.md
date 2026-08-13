# Codex task 010 — pixel-style Choco for a style comparison

## Why

The pet reads as choppy. Measured cause: the idle row's 6 frames are
independently generated, so 37–46% of pixels change between neighbours and the
silhouette drifts ~4 px — it is not one dog breathing, it is six similar dogs.
Photoreal fur is what makes that visible, and it also locks animation into the
expensive routes (video generation or per-pet rigging).

`hatch-pet` supports a `pixel` style preset. Pixel art is frame-stepped by
nature, so a low frame rate reads as style rather than as a defect, and a
limited palette with simple shapes should hold identity across frames far better
than rendered fur. The app's existing renderer (`FilterQuality.none`, frame
stepping, 8×11 atlas) is already the correct way to draw pixel art.

This task produces one pixel-style Choco so David can compare the two side by
side in the app. **It decides nothing** — it is evidence for a style decision.

## Deliverable

A packaged `.pettodopet` plus QA artifacts under
`~/Projects/apps/pettodo/artifacts/task-010/`.

## Inputs

- Source photos: `~/Projects/choco-pet/references/reference-01..05.jpg`
- Identity reference: `~/Projects/apps/pettodo/assets/pets/choco/pet_request.json`
  (see `description`, `pet_notes`) and the existing atlas
  `assets/pets/choco/spritesheet-extended.webp`
- Pack format to match: `~/Projects/apps/pettodo/artifacts/task-008/choco2-pack/pack.json`

## Requirements

- Run the installed `hatch-pet` skill. Style preset: **`pixel`** (explicit, not
  `auto`).
- Keep the v2 contract exactly: 8×11 atlas, 192×208 cells, 1536×2288,
  `spriteVersionNumber: 2`, all 9 animation rows plus both look rows, unused
  cells fully transparent.
- `pet_id`: `chocopx`. `display_name`: `Choco Pixel`. Neither may collide with
  the installed `choco` or `choco2`.
- Identity must stay recognisably Choco: chocolate-brown curly coat, silver-brown
  muzzle, floppy ears. Pixel art abstracts detail — keep the markings that make
  him identifiable at 192×208.
- Complete hatch-pet's own QA: contact sheet, look-direction sheet, chroma
  cleanup report with `ok: true`, atlas validation passing with no opaque
  chroma-key pixels.
- Package as `.pettodopet` — a zip of `pack.json`, `pet_request.json`, and
  `spritesheet-extended.webp` (see the task-008 pack for the exact shape).

## Constraints

- **Do not modify any app code.** This task produces assets only.
- **Do not commit or push.** Leave the artifacts for review.
- Do not touch `assets/pets/choco/` — the existing pet stays as it is, since the
  whole point is comparing them.

## Acceptance

- `artifacts/task-010/chocopx.pettodopet` exists and imports cleanly through the
  app's Settings → Import pet pack.
- QA artifacts present alongside it (contact sheet at minimum).
- Report which style decisions you made and anything the pixel preset could not
  preserve from Choco's identity.

# Task 014 — Pixel Choco as bundled canon + pixel-default hatchery (⚖️2026-08-24 拍板 A)

First: read `docs/IMPLEMENTATION-NOTES.md` and `docs/CODEX-TASK-010-pixel-choco.md`
(the style exploration that won). Task 010's output stopped early: only a 9-row
base atlas, no look rows, chroma despill NOT run (visible green fringe on the
sprite in-app). This task produces the finished, canonical pixel Choco.

## Goal

1. Re-run the `hatch-pet` pipeline (`~/.codex/skills/hatch-pet/`) end to end
   for pixel-style Choco using `artifacts/task-010/pet_request.json` as the
   request (same references, same style notes), completing EVERY stage:
   16 look-direction frames genuinely produced (not cardinal-mapped fill),
   `despill_chroma_edges.py` run, `validate_atlas.py` passing with zero opaque
   chroma-key pixels, contact sheet + QA artifacts present.
2. Replace the bundled canon: `assets/pets/choco/spritesheet-extended.webp`
   (8×11, 1536×2288) and any manifest fields that carry display name — the
   bundled pet stays `id: choco`, display name "Choco". The painterly
   spritesheet moves to `artifacts/task-014/painterly-archive/` (do not
   delete history).
3. Flip the hatch-pet skill default: `style_preset` defaults to `pixel` for
   future hatch runs (edit in `~/.codex/skills/hatch-pet/`, note the exact
   file/line in your report).

## Constraints

- **No app code changes** — assets and skill config only. (App-side dynamic
  registry already renders whatever the atlas contains.)
- Identity anchors non-negotiable: silver-brown muzzle mask, lighter brows,
  ear fringe, floppy ears — the reviewer compares against task-010's approved
  base look; do not restyle from scratch.
- Do not touch `artifacts/task-010/` originals; write to `artifacts/task-014/`.
- Do not commit or push.

## Acceptance

- `validate_atlas.py` ok:true, zero opaque chroma pixels, all 11 rows
  populated with per-row frame counts matching the request.
- Fresh-install app run (existing test build is fine) shows bundled Choco as
  pixel art in onboarding with NO green fringe at 3x zoom screenshot.
- QA artifacts: contact sheet, look-direction sheet, despill report.

# Task 013 — Pixel UI restyle "Cozy Pixel" (⚖️2026-08-24 David 拍板方向 A)

First: read `docs/IMPLEMENTATION-NOTES.md` (gotchas from every prior task) and
`docs/design/pixel-restyle/SPEC.md` (the authoritative token map / component
spec / test seam for this task). The visual canon is the five `.dc.html`
artboards in `docs/design/pixel-restyle/` — Direction A only (`Main`,
`Settings`, `Collection`, `Onboarding`); `HomeRetro` is an archived
comparison, do NOT implement it.

## Goal

Restyle the entire Flutter app to the "Cozy Pixel" language. **Structure,
navigation, copy, and behavior change zero** — this is a skin swap at the
theme/component layer. ADHD-first constraints hold: body text legibility must
not regress.

## Scope (files)

- `lib/ui/theme/*` — token updates per SPEC table (radii→StairBorder,
  shadows→hard offset, text styles→Pixelify Sans display + Baloo 2 body).
- New `lib/ui/theme/stair_border.dart` (custom ShapeBorder, the only new
  geometry logic) and pixel icon painters (new file(s) under `lib/ui/`).
- `pubspec.yaml` + `assets/fonts/` — wire Baloo 2 (ttf already in repo) and
  add Pixelify Sans (download ttf + OFL license file; if the sandbox has no
  network, leave a clearly marked TODO block in pubspec and report it —
  do not silently skip).
- All screens in `lib/ui/*.dart` — swap to the new components. The three
  screens with no artboard (`history_screen`, `hatch_request_screen`,
  `task_editor_sheet`) use the same component vocabulary; do not invent new
  patterns for them.
- Sprite rendering: pin FilterQuality to none everywhere sprites draw
  (home hero, collection thumbnails, onboarding rows, ceremony).

## Constraints

- Palette hex values do not change. Copy does not change. No layout
  reflow beyond what square corners force.
- Do not touch `lib/domain/`, `lib/application/`, `lib/data/`, or the
  sprite atlas/loader logic (except FilterQuality at the render sites).
- Do not modify or delete `lib/dev/` in this task.
- Do not commit or push — leave the working tree for review.

## Test seam (red first where applicable)

1. Existing 44 tests are the regression gate — all green, no assertion
   edits. If one fails, that is a finding to fix in your code, not the test.
2. New unit test for StairBorder path vertex sequence (large 12px/2-step and
   small 4px/1-step variants).
3. Golden snapshots for Home / Settings / Collection / Onboarding at 393pt
   width (new goldens are the deliverable baseline, generate deterministically).

## Acceptance

- `flutter analyze` clean; full test suite green 3x consecutively.
- iOS simulator build + real launch AND Android emulator build + real launch
  (`adb logcat` shows no `E flutter`) — the 07-22 rule: a package that only
  compiles is not verified.
- Four screens visually match the Direction A artboards (reviewer does the
  eyeball pass; your job is that goldens exist and match your build).

## ADHD mapping (per PRODUCT-PRINCIPLES.md)

Visual-language unification; no new feature surface. Legibility floor: body
copy stays Baloo 2 / ≥15px equivalent — pixel font is display-only.

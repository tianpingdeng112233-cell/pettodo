# Task 008 — Own-Pet Hatch Loop, Wave 1 (concierge, no backend)

**Decision (David, 2026-08-12):** photo → your-own-pet is THE core feature of PetTodo.
008 jumps the queue ahead of 002/003/004.

**ADHD-first mapping (required by PRODUCT-PRINCIPLES.md):** emotional transplant —
*your own* pet waiting for you is the dopamine anchor that beats app-abandonment /
motivation deficit. The hatch wait state is zero-pressure by design (no deadline, no
shame if you never finish the flow) — rejection-sensitivity safe.

## Context

- Pets are currently loaded ONLY from bundled assets: `assets/pets/manifest.json`
  → `SpriteAtlasLoader` (`lib/sprite/sprite_atlas.dart`, rootBundle-only). Single pet
  `choco`. `AppState.selectedPetId` already exists (`lib/domain/app_state.dart`).
- Sprite generation happens OFF-DEVICE via David's local `hatch-pet` pipeline
  (Codex skill). Its output per pet is exactly what `assets/pets/choco/` contains:
  `pet_request.json` (atlas metadata, 8×11 grid, 192×208 cells) +
  `spritesheet-extended.webp`. Wave 1 productizes the *loop around* that pipeline,
  not the pipeline itself. No backend, no network code.
- Onboarding already has a disabled "Upload your own pet's photo" card with a
  `Soon` badge (`lib/ui/onboarding_screen.dart`, `_FuturePetChoice`).

## The loop to build (all local)

1. **Hatch request (photo capture)** — Onboarding card becomes active; same entry
   in Settings ("Hatch your own pet"). Flow: pick 1–5 photos (camera or gallery via
   `image_picker`) → optional pet name → saved locally as
   `<documents>/hatch_request/` (photos + `request.json`: requestId, petName,
   createdAt). Exactly one pending request at a time.
2. **Egg / incubation state** — While a request is pending, Home shows a gentle egg
   state for the pet slot (does NOT replace current active pet; a small egg element
   beside/near the pet is fine). Copy is zero-pressure, e.g. "Your pet is on its
   way — no rush." Request is cancellable without ceremony or guilt copy.
3. **Request export** — "Send to the hatchery": zips the request folder and opens
   the system share sheet (`share_plus`). (Seed-stage transport is manual: David
   receives it, runs the pipeline, sends back a pack.)
4. **Pet pack import** — Settings (+ a hint on the egg state): import a
   `.pettodopet` file (a zip; use `file_picker`, accept .pettodopet and .zip).
   Contents: `pack.json` `{formatVersion: 1, id, display_name, treat: {name, emoji}}`
   + `pet_request.json` + `spritesheet-extended.webp`.
   Validate before install: required files present, formatVersion == 1, id matches
   `^[a-z0-9_-]+$`, atlas metadata parses and grid is 8×11 @192×208, spritesheet
   decodes and pixel dims match metadata. Same-id import replaces (upgrade path).
   Install to `<documents>/pets/<id>/`.
5. **Dynamic pet registry** — Runtime pet list = bundled manifest pets + installed
   packs. `SpriteAtlasLoader` learns to load a pet from the filesystem as well as
   rootBundle. Installed pets appear everywhere choco does (selection, collection).
6. **Hatch ceremony** — On successful import: celebration moment (reuse the
   existing 小剧场/celebration infra from the 005 skin), auto-select the new pet,
   clear a matching pending request. This is the payoff frame — make it warm, not
   loud.

## Constraints

- **No backend, no network.** Everything on-device; transport is the share sheet.
- New deps allowed: `image_picker`, `share_plus`, `file_picker`, `archive`. Nothing else.
- iOS: add `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` (English).
- UI: reuse existing 1a theme tokens (`lib/ui/theme/`), minimal new chrome, English
  copy only. A designer pass will follow — keep layout simple and token-driven.
- State: if `AppState` gains fields, bump schema (v3→v4) with a migration test.
  **Red line: existing users must keep choco + all progress + history untouched.**
- Zero-punishment red line holds: no failure states with negative pet reactions;
  a rejected/invalid pack shows a calm, factual message ("This pack doesn't fit —
  ask for a fresh one"), pet unaffected.
- Do NOT commit or push. Leave the working tree for review.

## Known gotchas (docs/IMPLEMENTATION-NOTES.md — read it first)

- **Android release resource shrink** strips resources referenced only from Dart
  strings (the 6c886af black-screen incident). New plugins bring Android resources —
  verify a RELEASE build actually launches on both platforms.
- flutter_test zone traps; timing assertions must follow the runAsync-synchronous
  pattern (005 lesson); run the suite 5× to prove no parallel flake.
- JDK is pinned to openjdk@21 via `flutter config --jdk-dir`.
- APFS case-insensitivity: never `git rm` paths differing only by case.

## Acceptance

- `flutter analyze` clean; full test suite green 5× consecutively.
- Tests cover: pack validation (missing file / bad grid / bad id / dim mismatch /
  same-id replace), registry merge (bundled + installed), request lifecycle
  (create → export → cancel; create → import matching pack → cleared), AppState
  migration, semantics on all new UI (no merged-node regressions — 005R lesson).
- End-to-end proof: build a real `.pettodopet` from `assets/pets/choco/` contents
  (id `choco2`), import it in the simulator, see ceremony + switch; screenshots.
- Both platforms genuinely launched once each (iOS simulator + Android emulator
  `meetpr`, `adb logcat` clean of `E flutter`) — in RELEASE mode on Android.

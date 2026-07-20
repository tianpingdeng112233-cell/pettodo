# Task 001 — PetTodo iOS Concierge MVP (v1)

## Goal

Build the complete v1 of PetTodo: a local-only iOS SwiftUI app where the user "raises" their own pet (bundled sprite-sheet pet) by completing 3 daily tasks. Full product context is in `docs/DESIGN.md` (Chinese; the "MVP Spec（v1）" section is the contract). This card is self-contained — if the card and DESIGN.md ever conflict, the card wins.

## Environment

- Repo root: this repo (`~/Projects/apps/pettodo`), fresh, no Xcode project yet.
- Xcode 26.6, iOS 17+ deployment target, iPhone-only, portrait-only, 393pt design width.
- Create the Xcode project programmatically with the `xcodeproj` ruby gem (installed, v1.27.0). Do NOT hand-write a pbxproj. Project name `PetTodo`, single app target, bundle id `com.davidshi.pettodo`, signing team `28JW4SA779`, automatic signing.
- Swift 5.9+/SwiftUI/SwiftData. No third-party dependencies, no SPM packages, no analytics SDKs, no networking of any kind.

## Pet sprite assets (already in repo)

`Assets/Pets/choco/`:
- `spritesheet-extended.webp` — 1536×2288 RGBA atlas, 8 columns × 11 rows, cell 192×208. `UIImage` decodes webp natively on iOS 14+.
- `pet_request.json` — atlas metadata: per-row state name, frame count, purpose. Rows: idle(6f), running-right(8f), running-left(8f), waving(4f), jumping(5f), failed(8f), waiting(6f), running(6f), review(6f), look-row-9(8 directions), look-row-10(8 directions).
- Build a small `SpriteAtlas` loader that slices frames from the atlas per `pet_request.json` (parse the JSON at runtime from the bundle; do not hardcode row indices beyond a typed state enum). Render animation loops in SwiftUI (e.g. `TimelineView`/`Timer` driving a frame index over a cropped `CGImage`; SpriteKit is also acceptable if simpler). Target ~8 fps loop, pixel-crisp scaling (`.interpolation(.none)` style).
- Ship the atlas + jsons as bundle resources. Architecture must allow adding a second pet folder later without code changes (pets discovered by scanning `Pets/` bundle subdirectories).

## HARD RED LINE (product constitution — violating this fails review)

The pet must NEVER be harmed, sad, or degraded by user inaction:
- NEVER use the `failed` sprite row in response to missed/incomplete tasks. (`failed` row may remain unused entirely in v1.)
- No streaks, no streak-loss, no "X days missed", no guilt copy, no red badges, no overdue markers.
- Unfinished tasks roll over silently: tomorrow shows the same 3 tasks fresh, zero reference to yesterday.
- If notification permission is denied: never re-ask, never show in-app prompts/red dots about it.

## Features (v1 scope, complete list)

1. **Onboarding** (first launch only): pick pet (v1: only Choco, but UI is a list), name the pet (default "Choco"), create 3 daily tasks (free-text titles, Chinese placeholder examples like「喝水 8 杯」「背 20 个单词」「遛狗」). Then straight into Home.
2. **Home screen** (the app IS this screen): pet front and center playing `idle` loop, pet name, today's 3 tasks below as large tap targets. Tap task → checked; pet immediately plays `jumping` (or `waving`) loop for ~2s with haptic, then returns to idle. All 3 done → longer celebration: `jumping` + confetti-ish particle or `review` loop + affectionate line in pet's voice (e.g.「Choco 满足地蹭了蹭你」).
3. **Tasks**: exactly 3 daily recurring tasks. Editable titles anytime (Settings). No priorities, no due times, no subtasks, cannot add a 4th. Day boundary = device-local midnight; on new day all tasks reset to unchecked (silent rollover).
4. **Unlocks**: cumulative lifetime completion count drives decor unlocks at 5/15/30 completions (3 decor items, e.g. 小球/垫子/小屋 — simple SF Symbol or emoji rendered near the pet on Home). Unlock moment: brief celebratory banner + pet `waving`. Progress visible in Settings (e.g.「已完成 12 次 · 下一个解锁还差 3 次」). No loss, no decay.
5. **Notification**: one daily local notification at a user-set time (default 20:00, time picker in Settings; single toggle). Copy in the pet's voice, inviting not nagging, rotate a few variants:「Choco 在窗边等你回来～」style. Request permission only when the user first enables/keeps the toggle on during onboarding completion. Denied → toggle shows off, no further prompts ever.
6. **Event log + export**: SwiftData records events: `app_open` (scenePhase active), `task_complete` (taskIndex), `all_done`, `notification_tap`, `unlock` — each with timestamp. Settings has「导出数据」→ serializes all events to pretty JSON → system share sheet.
7. **Settings**: rename pet, edit 3 task titles, notification toggle+time, unlock progress, export data, app version.

## UI language & tone

All UI copy in Chinese (mainland, casual warm tone). Code identifiers/comments in English. No third-party fonts. Design: warm, minimal, the pet is the hero — big pet, soft background color, tasks as 3 rounded cards. This is a scannable one-screen app, not a productivity dashboard.

## Testing & acceptance

- Unit tests (XCTest target, macOS-host-safe pure-logic tests are fine but the app target is iOS-only; keep logic in testable plain types): day-rollover semantics (crossing midnight resets checks, cumulative count preserved), unlock threshold logic (5/15/30 edges), event log encoding, SpriteAtlas frame-rect math from `pet_request.json`.
- `xcodebuild -project PetTodo.xcodeproj -scheme PetTodo -destination 'platform=iOS Simulator,name=iPhone 16' build` must succeed with zero warnings-as-errors issues.
- Tests pass via `xcodebuild test` on the same simulator destination.
- App launches in simulator: onboarding → home → completing tasks animates pet → settings export produces JSON.

## Deliverable discipline

- ONE atomic, reviewable working-tree diff. Do NOT `git commit`, do NOT `git push` — the orchestrator handles git.
- Do not modify `Assets/Pets/choco/*`, `docs/DESIGN.md`, or this card.
- Write a short `docs/IMPLEMENTATION-NOTES.md`: key decisions, how to add a second pet, anything you'd flag for review.
- No secrets, no placeholder TODO stubs for in-scope features — v1 scope above is complete and final; anything not listed is out of scope (no widget, no backend, no accounts, no IAP).

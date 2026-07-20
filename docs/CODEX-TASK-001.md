# Task 001 — PetTodo Flutter MVP 底座 (v1, iOS+Android)

> Supersedes the earlier SwiftUI card (direction changed 2026-07-20: cross-platform Flutter, designer will deliver visual design later).

## Goal

Build the v1 foundation of PetTodo: a local-only Flutter app (iOS + Android, single codebase) where the user raises a bundled sprite-sheet pet by completing 3 daily tasks. A designer will restyle the UI later — so this card is **engine-first**: sprite renderer, data layer, notifications, export must be production-grade; visual styling stays clean-but-minimal placeholder (warm background, big pet, 3 rounded task cards) with a strict separation so reskinning later touches only the presentation layer.

Product context: `docs/DESIGN.md` (Chinese). Designer brief: `docs/DESIGN-BRIEF.md`. If they conflict with this card, the card wins.

## Environment

- Repo root: `~/Projects/apps/pettodo` (this repo). No Flutter project yet — run `flutter create --org com.davidshi --platforms ios,android .` at repo root (project name `pettodo`), then merge/keep the existing root `.gitignore` plus Flutter's.
- Flutter stable (just installed via Homebrew; binary at `/opt/homebrew/bin/flutter`). Xcode 26.6 present. Android SDK may still be installing — see Acceptance for what's required vs best-effort.
- Dart 3.x, null-safe. Dependencies allowed: `path_provider`, `share_plus`, `flutter_local_notifications`, and (optional, only if it genuinely simplifies sprite work) `flame`. Nothing else — no state-management framework (use `ChangeNotifier`/`ValueNotifier`), no analytics, no networking of any kind.

## Pet sprite assets (already in repo)

`Assets/Pets/choco/`:
- `spritesheet-extended.webp` — 1536×2288 RGBA atlas, 8 columns × 11 rows, cell 192×208. Flutter decodes webp natively.
- `pet_request.json` — atlas metadata: per-row state name, frame count, purpose. Rows: idle(6f), running-right(8f), running-left(8f), waving(4f), jumping(5f), failed(8f), waiting(6f), running(6f), review(6f), look-row-9(8 dirs), look-row-10(8 dirs).

Requirements:
- You may `git mv` the assets to Flutter-conventional `assets/pets/choco/` and declare them in `pubspec.yaml`.
- Build a `SpriteAtlas` loader that parses `pet_request.json` at runtime (typed state enum is fine, but frame counts/rows come from JSON, not hardcode).
- Render animation loops at ~8 fps, pixel-crisp (`FilterQuality.none`), via `CustomPainter` + `Ticker` using `canvas.drawImageRect` over the decoded atlas — or Flame's `SpriteAnimation` if you take the flame dependency. Document the choice and tradeoff in IMPLEMENTATION-NOTES.
- Architecture must allow adding a second pet folder later without code changes (pets discovered from a bundled manifest or asset listing).

## HARD RED LINE (product constitution — violating this fails review)

The pet must NEVER be harmed, sad, or degraded by user inaction:
- NEVER use the `failed` sprite row in response to missed/incomplete tasks (it may stay unused in v1).
- No streaks, no streak-loss, no "X days missed", no guilt copy, no red badges, no overdue markers.
- Unfinished tasks roll over silently: tomorrow shows the same 3 tasks fresh, zero reference to yesterday.
- Notification permission denied → never re-ask, never show in-app prompts/red dots about it.

## Features (v1 scope, complete list)

1. **Onboarding** (first launch only): pick pet (v1: only Choco, list UI with a greyed-out「上传自家宠物照片(即将上线)」row), name the pet (default "Choco"), create 3 daily tasks (free text, Chinese placeholders:「喝水 8 杯」「背 20 个单词」「遛狗」), notification opt-in page (invitation-tone copy + time picker default 20:00). Then Home.
2. **Home**: pet front and center playing `idle` loop, pet name, unlocked decor items near the pet, 3 task cards below. Tap task → checked; pet plays `jumping` (or `waving`) ~2s with haptic, back to idle. All 3 done → longer celebration: `review` or `jumping` loop + simple particle burst + affectionate line in pet's voice (「Choco 满足地蹭了蹭你」).
3. **Tasks**: exactly 3 daily recurring tasks, editable titles (Settings), no priorities/due-times/subtasks, no 4th task. Day boundary = device-local midnight; new day resets checks silently (also handle app-resume-across-midnight via lifecycle observer).
4. **Unlocks**: cumulative lifetime completion count unlocks 3 decor items at 5/15/30 (emoji or simple shapes near pet is fine for placeholder). Unlock moment: banner + pet `waving`. Progress line in Settings (「已完成 12 次 · 下一个解锁还差 3 次」). No loss, no decay.
5. **Notifications**: one daily local notification at user-set time (default 20:00, editable, single toggle in Settings). Pet-voice invitation copy, rotate ≥3 variants (「Choco 在窗边等你回来～」style). Permission requested once during onboarding opt-in; denied → toggle off, never re-prompt.
6. **Event log + export**: append-only local event log (JSONL file via `path_provider`): `app_open` (app resumed/launched), `task_complete` (task index), `all_done`, `notification_tap`, `unlock` — each with ISO timestamp. Settings「导出数据」→ share the JSON via `share_plus`.
7. **Settings**: rename pet, edit 3 task titles, notification toggle+time, unlock progress, export, app version.

## Architecture & style

- Clean separation: `lib/domain/` (pure Dart logic: task day-rollover, unlock thresholds, event log — fully unit-testable, zero Flutter imports), `lib/data/` (persistence: JSON file for app state, JSONL for events), `lib/sprite/` (atlas loader + renderer widget), `lib/ui/` (screens/widgets — the only layer the designer reskin will touch).
- App state persisted as a single JSON file (no DB dependency).
- All UI copy in Chinese (mainland, casual warm tone); code identifiers/comments in English.
- `flutter analyze` must be clean with default lints (`flutter_lints`).

## Testing & acceptance

- Unit tests (`flutter test`): day-rollover semantics (midnight crossing resets checks, cumulative count preserved), unlock threshold edges (4→5, 14→15, 29→30), event JSONL round-trip, sprite frame-rect math from `pet_request.json`.
- REQUIRED to pass before you finish: `flutter analyze` clean; `flutter test` green; `flutter build ios --simulator --no-codesign` succeeds.
- BEST-EFFORT (Android SDK may still be installing): `flutter build apk --debug`. If the Android toolchain is unavailable, note it in IMPLEMENTATION-NOTES and ensure nothing in the code is iOS-only (no platform-gated feature without an Android path).

## Deliverable discipline

- ONE atomic, reviewable working-tree diff. Do NOT `git commit`, do NOT `git push` — the orchestrator handles git.
- Do not modify `docs/DESIGN.md`, `docs/DESIGN-BRIEF.md`, or this card. (Moving `Assets/` → `assets/` via git mv is allowed per above.)
- Write `docs/IMPLEMENTATION-NOTES.md`: key decisions (esp. sprite rendering approach + how to add pet #2 + reskin seam), anything you'd flag for review, Android build status.
- No secrets, no TODO stubs for in-scope features; anything not listed is out of scope (no widget, no backend, no accounts, no IAP, no photo upload).

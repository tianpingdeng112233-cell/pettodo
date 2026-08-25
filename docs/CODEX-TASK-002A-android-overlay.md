# Task 002-A — Android floating pet overlay (⚖️2026-08-25 David: Android first, full speed)

First: read `docs/CODEX-TASK-002.md` (the approved product canon for the
ambient layer — its Android section, constraints, and red lines all apply
verbatim) and `docs/IMPLEMENTATION-NOTES.md`. This card narrows 002 to the
**Android overlay half only** — the iOS widget ships as a later card — and
updates it for the pixel era. App display name is now **Pawside**.

## Scope

- Floating overlay pet via `SYSTEM_ALERT_WINDOW`(「显示在其他应用上层」):
  visible over the launcher and other apps, draggable, idle-animating,
  celebration animation within 1s of a task being completed in-app.
- Settings toggle「让 {pet} 留在屏幕上」. Permission denied → toggle off,
  never re-prompt (002 policy).
- Foreground service as needed to survive app background. Verify against
  current Android 14/15 foreground-service-type rules and document the
  chosen type + rationale in IMPLEMENTATION-NOTES (`specialUse` vs none —
  check the actual current constraint, do not guess). The mandatory
  persistent notification uses calm companion wording ("{pet} is keeping
  you company") — never task pressure; it must respect the app's
  zero-punishment copy rules.
- Sprite source = the bundled pixel canon atlas (8×11, 192×208 cells).
  Reuse 001's atlas slicing logic or a build-time pre-slice script — do not
  hand-edit frames, do not fork sprite state logic. Nearest-neighbor
  scaling only (pixel canon: no smoothing).
- Tap on the pet opens the app (single sensible default; no other overlay
  gestures this wave). Position persists across restarts.
- Battery discipline: animation pauses when screen off; modest frame rate
  (the in-app idle cadence, not 60fps).

## Out of scope

- iOS widget / StandBy (later card), Live Activity (Task 003).
- Task text/progress on the overlay — the overlay is the pet only this
  wave (002's neutral「今天 2/3」idea stays parked for the widget card).
- Any change to in-app screens beyond the Settings toggle.

## Red lines (from 002, restated)

- Overlay never shows negative states: incomplete tasks = calm idle, never
  sad, no badges, no counts.
- Overlay permission and the foreground-service notification must never
  nag: one ask, decline is final until the user flips the toggle again.

## Test seam

1. Existing 50 tests are the regression gate — all green, no assertion edits.
2. Platform-channel contract: unit tests on the Dart side for the overlay
   controller (enable/disable/celebration event → channel invocations,
   permission-denied → toggle reverts) against a mocked channel.
3. Native side: a deterministic frame-slicer test if a build script slices
   frames (input atlas → expected cell count/size).

## Acceptance

- `flutter analyze` clean; full suite green 3x.
- Emulator (AVD meetpr) real run: grant overlay permission via
  `adb shell appops set com.davidshi.pettodo SYSTEM_ALERT_WINDOW allow`,
  toggle on → pet floats over launcher AND over another app, drags, idle
  loop animates; complete a task in-app → overlay celebration ≤1s;
  toggle off → overlay gone; app backgrounded → overlay survives.
  Screenshot evidence at each step (`adb exec-out screencap`).
- Release build launch check per the 07-22 rule (`E flutter` = 0), overlay
  service resources survive release shrinking (keep.xml if needed — the
  ic_notification lesson applies to any resource referenced only from
  Dart/strings).
- No commit, no push — leave the tree for review.

## ADHD mapping

Ppl-H1「眼不见即不存在」: the pet living on the screen is the symptom-level
fix — the external anchor stays in view without the user having to remember
to open an app. Zero-punishment presence, not a reminder surface.

# Task 002 — 常驻屏幕层（Ambient Pet）: Android 悬浮宠物 + iOS 桌面 Widget

> Status: QUEUED — do not start until Task 001 (core app) is merged. Depends on 001's sprite engine and data layer.
> Product driver (2026-07-20, David): the mobile pet must be able to "stay on screen" like the desktop codex pet — ambient presence IS the validated loop, not app-opening.

## Platform mapping (agreed reality)

- **Android = full experience**: floating overlay pet (SYSTEM_ALERT_WINDOW, user grants「显示在其他应用上层」), draggable, frame-animated (idle loop), reacts when a task is completed in-app (celebration animation). Toggle in Settings:「让 {pet} 留在屏幕上」. Overlay must survive app background; foreground service as needed.
- **iOS = three-surface plan (confirmed by David 2026-07-20)**:
  1. **WidgetKit widget (this task)** — small: pet frame + today 2/3; medium: pet frame + 3 INTERACTIVE task buttons (iOS 17 App Intents — completing a task from the home screen without opening the app is the core ADHD win). Pre-scheduled timeline gives the pet a daily rhythm for free (morning stretch / noon nap / evening waiting frames); app triggers WidgetCenter reload on every task completion. SwiftUI, App Group shared JSON snapshot.
  2. **StandBy** — comes free with the widget; ensure small/medium render legibly at StandBy scale and the night timeline entry shows the sleeping frame (bedside companion scene).
  3. **Live Activity / Dynamic Island** — NOT in 002; queued as Task 003 (evening companion session + all-done celebration).

## Constraints

- Reuse 001's atlas assets and state model; do not fork sprite logic — export shared frame data (pre-sliced PNGs for widget/overlay if runtime atlas slicing is impractical natively; generate them in a build script, do not hand-edit).
- RED LINE unchanged: ambient pet never shows negative states; if tasks are incomplete the pet is just calmly idle/waiting — never sad, no badges, no counts on the widget beyond neutral progress (「今天 2/3」 is OK, overdue framing is not).
- Overlay permission denied on Android → toggle off, никогда re-prompt (same policy as notifications).
- One atomic diff, no commit; implementation notes appended to docs/IMPLEMENTATION-NOTES.md.

## Acceptance

- Android: overlay pet visible over launcher and other apps, draggable, idle-animating; toggle on/off works; task completion in app triggers overlay celebration within 1s (shared state via platform channel or file watch).
- iOS: widget shows pet + today progress; updates after each task completion (WidgetCenter reload from app side); builds and passes existing tests; `flutter analyze` clean.

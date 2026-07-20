# Task 002 — 常驻屏幕层（Ambient Pet）: Android 悬浮宠物 + iOS 桌面 Widget

> Status: QUEUED — do not start until Task 001 (core app) is merged. Depends on 001's sprite engine and data layer.
> Product driver (2026-07-20, David): the mobile pet must be able to "stay on screen" like the desktop codex pet — ambient presence IS the validated loop, not app-opening.

## Platform mapping (agreed reality)

- **Android = full experience**: floating overlay pet (SYSTEM_ALERT_WINDOW, user grants「显示在其他应用上层」), draggable, frame-animated (idle loop), reacts when a task is completed in-app (celebration animation). Toggle in Settings:「让 {pet} 留在屏幕上」. Overlay must survive app background; foreground service as needed.
- **iOS = honest ceiling**: home-screen WidgetKit widget (small + medium) showing the pet's current frame/state + today's task progress (e.g. 2/3), refreshed within timeline budget (state snapshots, not continuous animation). Written in SwiftUI, data shared via App Group (core app writes a compact JSON snapshot on every state change). Celebration moments MAY use a brief Live Activity later — out of scope for 002 unless trivial.

## Constraints

- Reuse 001's atlas assets and state model; do not fork sprite logic — export shared frame data (pre-sliced PNGs for widget/overlay if runtime atlas slicing is impractical natively; generate them in a build script, do not hand-edit).
- RED LINE unchanged: ambient pet never shows negative states; if tasks are incomplete the pet is just calmly idle/waiting — never sad, no badges, no counts on the widget beyond neutral progress (「今天 2/3」 is OK, overdue framing is not).
- Overlay permission denied on Android → toggle off, никогда re-prompt (same policy as notifications).
- One atomic diff, no commit; implementation notes appended to docs/IMPLEMENTATION-NOTES.md.

## Acceptance

- Android: overlay pet visible over launcher and other apps, draggable, idle-animating; toggle on/off works; task completion in app triggers overlay celebration within 1s (shared state via platform channel or file watch).
- iOS: widget shows pet + today progress; updates after each task completion (WidgetCenter reload from app side); builds and passes existing tests; `flutter analyze` clean.

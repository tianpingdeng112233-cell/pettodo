# Task 005 — Apply approved design "1a 暖阳客厅" to the Flutter UI layer

> Status: QUEUED — start after Task 001 is merged. Touches ONLY `lib/ui/` (+ theme/fonts/pubspec assets); domain/data/sprite layers are frozen except for surface API needs.
> Design authority: designer-delivered exploration doc, David approved direction **1a** (2026-07-20).

## Reference files (in repo)

- `docs/design/home-direction-exploration.dc.html` — full design source (3 turns).
- `docs/design/rendered/option-1a.html` — Home, chosen visual direction「暖阳客厅 · 奶油蜜桃 · 软圆卡通」with exact inline styles (colors/spacing/shadows) and EN copy.
- `docs/design/rendered/option-2a.html` — Onboarding: 4 steps, Choco first-person voice.
- `docs/design/rendered/option-2b.html` — Home moment states: task complete / 3-of-3 "Little Theater" celebration / unlock banner.
- `docs/design/rendered/option-2c.html` — Settings: rename + task edit (live sync to Home), no-pressure collection view (no progress bars, no deadlines).
- `docs/design/rendered/option-3a.html` — Notification lock-screen style + 3 rotating voice variants (EN copy is canonical).
- `docs/design/rendered/option-3b.html` — **UI Kit v1**: component inventory with names, sizes, states, hex values. Treat as the design-token source of truth.

These rendered HTML files carry computed inline styles — copy values verbatim (colors, radii, shadows, font sizes, paddings). Do not eyeball.

## Scope

1. **Theme layer**: build `lib/ui/theme/` (colors, text styles, radii, shadows, spacing) from option-3b tokens. No hardcoded values in screen widgets.
2. **Fonts**: bundle Baloo 2 (OFL license — download via Google Fonts, declare in pubspec) for display text; system font for body. Do not fetch fonts at runtime.
3. **Home** (per 1a + 2b): warm gradient bg + sun halo, date greeting line, center stage (sprite renderer from 001 replaces the dashed placeholder box, 192×208 with breath idle motion — the sprite widget already animates; the "breath" scale applies to container), ground shadow ellipse, pet name (Baloo 2), pet status line, unlocked-decor row, "Today's three little things" + 3 white rounded task cards. Implement ALL moment states from 2b: single-complete reaction, 3/3 Little Theater overlay (with "Thank you, {petName}" button), unlock banner slide-down.
4. **Onboarding** (per 2a): 4 steps, Choco first-person copy.
5. **Settings** (per 2c): rename/task edit live-sync, notification toggle+time, collection view (unlocks) with zero pressure framing, export, version.
6. **Notification copy** (per 3a): replace 001's placeholder variants with the 3 EN variants from the design.
7. **Language**: the design's EN copy is canonical product copy (overseas-first). If 001 shipped Chinese strings, replace with design EN strings now; ARB extraction stays Task 004.

## Red lines (unchanged, designer already complied — keep it that way)

No streaks, no overdue markers, no sad pet, silent rollover, notifications max 1/day at user-chosen time, invitation tone only, collection view has no progress bars/deadlines.

## Acceptance

- `flutter analyze` clean; `flutter test` green (update golden/widget tests as needed); `flutter build ios --simulator --no-codesign` and `flutter build apk --debug` (JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home) both succeed.
- Side-by-side visual parity: iOS simulator screenshots vs rendered reference HTML for Home (idle + all moment states), Onboarding steps, Settings. Reviewer will compare — spacing/colors must match the reference, not approximate it.
- One atomic diff, no commit. Do not modify docs/ (except appending to IMPLEMENTATION-NOTES.md).

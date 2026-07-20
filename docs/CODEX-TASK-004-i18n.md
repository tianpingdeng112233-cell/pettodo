# Task 004 — i18n: English-first, Chinese secondary

> Status: QUEUED — start after Task 001 lands. Light card.
> Strategy driver (2026-07-20, David): overseas market first. Product language = English (first-class), Chinese kept for the Chinese-speaking seed-validation pool.

## Scope

- Introduce standard Flutter i18n (`flutter_localizations` + `intl`, ARB files): `app_en.arb` (template/default) + `app_zh.arb`.
- Migrate ALL user-facing strings out of widgets into ARB. Locale resolution: system locale, fallback `en`.
- English copy is NOT a translation of the Chinese — it must be written natively in the warm pet-voice register (e.g. notification variants like "Choco is waiting by the window for you ~" tone; adapt, don't transliterate). Chinese copy keeps the existing 07-20 tone.
- Placeholder task examples localized: en「Drink 8 glasses of water / Learn 20 words / Walk the dog」.
- Red-line language rules apply in BOTH languages: invitation never nagging, zero guilt vocabulary.

## Acceptance

- `flutter analyze` clean, `flutter test` green, no hardcoded user-facing literals left in `lib/ui/` (grep check).
- App renders correctly in en and zh locales (manual sim check both).
- One atomic diff, no commit.

# Task 005-R — Rework: semantics boundaries + overflow (targeted fix round 1)

> Follow-up to Task 005 (uncommitted diff in working tree). Root cause diagnosed by orchestrator; apply exactly this scope, nothing else.

## Bug 1 (blocker): entire screens collapse into ONE merged accessibility node

Evidence: `flutter test test/semantics_dump_test.dart` (temporary dump test in repo) — onboarding page 1 compiles to a single SemanticsNode with `isButton` + concatenated label of every text on the page ("Hi, I'm Choco! … That's the one That's the one"). Same on device (iOS a11y snapshot shows one giant button). VoiceOver users get an unreadable blob; UI automation cannot target anything. v1 had the same latent defect masked by the AppBar's built-in boundaries.

Root cause: hand-rolled UI has NO semantic boundaries — custom `Semantics(button: true, label: …)` widgets default `container: false`, so all configs merge upward into the page node.

Required fix pattern, applied to EVERY interactive element in `lib/ui/` (onboarding buttons, pet-choice rows, notification enable/skip/time controls, home settings gear, home task cards, all Settings rows/GestureDetectors, Little Theater dismiss button, collection entries):

- The `Semantics` widget must sit ABOVE the gesture widget (InkWell/InkResponse/GestureDetector) so the tap action merges into it, and must set `container: true` plus the correct flags (`button: true`, `enabled:`, `checked:` where applicable).
- Where an inner `Text` already carries the visible label, drop the explicit `label:` (avoid "That's the one That's the one" duplication). Keep explicit `label:` only for icon-only controls (e.g. Settings gear → 'Settings').
- Pet sprite tap region (if present) gets `Semantics(container: true, button: true, label: petName)`.
- Purely decorative elements (halo, particles, ground shadow, sprite placeholder art) get `ExcludeSemantics` or no semantics — they must NOT contribute text to parent nodes.

## Bug 2: RenderFlex overflow

`Column` at `lib/ui/onboarding_screen.dart:224` overflows by 5px at 800×600 logical viewport (small devices / SE class). Make each onboarding page overflow-safe (e.g. `SingleChildScrollView` + `ConstrainedBox`/spacing diet) WITHOUT changing the 393pt design look.

## Acceptance

- Convert `test/semantics_dump_test.dart` into a real regression test `test/semantics_boundaries_test.dart`: with `tester.ensureSemantics()`, assert that onboarding page 1 exposes a SEPARATE tappable button node labeled "That's the one" (e.g. `find.bySemanticsLabel`), and that Home (reuse the fake-loader pattern from `test/home_tap_flow_test.dart`) exposes 3 distinct task-card button nodes plus a 'Settings' button node. Delete the temporary dump test.
- `flutter analyze` clean; `flutter test` all green (no RenderFlex overflow exceptions in any test).
- Do not touch domain/data/sprite layers, docs, or unrelated UI styling. One atomic diff on top of the current working tree, no commit. Append a short 005-R section to docs/IMPLEMENTATION-NOTES.md.

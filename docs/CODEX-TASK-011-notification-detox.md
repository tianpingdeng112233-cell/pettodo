# Codex task 011 — notification de-debt + anti-habituation engineering

**ADHD mapping (required by PRODUCT-PRINCIPLES):** current invitation copy
("waiting by the window", "come home") creates emotional debt — guilt is the #1
abandonment trigger for pet-based apps (first-hand Reddit research, 2026-08-13).
And ADHD brains filter out repeated notification patterns entirely (alarm
fatigue), so fixed wording + fixed time = invisible within weeks.

Decision已拍板 (David, 2026-08-13): absence semantics = **decoupled** — the pet
is living its own good day; opening the app is *joining* it, never compensating
it. The pet never waits, never misses you, never asks you to come.

## Scope

`lib/data/notification_service.dart` + its templates, minimal touches elsewhere,
plus tests. This is the daily-invitation channel ONLY. Do not redesign
per-task reminders beyond what item 4 says.

## Changes

### 1. Rewrite the invitation template pool (copy provided — use verbatim)

Replace `_invitationTemplates` with exactly this pool. Each is (title, body).
`{pet}` substitution stays as-is.

1. `{pet} found a sunbeam` / `It kept moving across the floor. {pet} followed it the whole afternoon.`
2. `A bird visited the window` / `{pet} watched it hop around the sill. Neither of them blinked much.`
3. `Big stretch report` / `Front paws way out, tail up high. {pet} rates it a perfect ten.`
4. `{pet} guarded the couch today` / `Nothing got past. The cushions are all accounted for.`
5. `Evening light is in` / `{pet} is curled up in the warmest corner of the room.`
6. `{pet} did one little thing today` / `Sniffed the whole hallway, twice. Very thorough work.`
7. `Nap update from {pet}` / `Three naps, all excellent. The afternoon one was the best.`
8. `{pet} heard something outside` / `Investigated bravely. It was leaves. Case closed.`
9. `The house is cozy tonight` / `{pet} made a nest out of the soft blanket. Engineering at its finest.`
10. `{pet} practiced looking cute` / `No practice was needed, honestly.`
11. `Small adventure today` / `{pet} discovered a new smell by the door and thought about it a lot.`
12. `{pet} is watching the sky` / `Clouds today. Slow ones. Good watching.`

Tone rules these were written to (verify any future edits against them):
- The pet reports ITS OWN day. No waiting, missing, asking, or summoning.
- Forbidden framings, either side: "waiting for you / miss you / come back /
  don't forget / you've got this / you can do it". No imperatives aimed at the
  user. No questions that request presence.
- Warm, small, concrete. One image per notification.

### 2. Random selection, not date-rotation

Current code picks `dayOffset % length` — a fixed rotation the brain learns to
filter. Replace with random pick per scheduled day, with the constraint that the
same template is not used two consecutive scheduled days (track by index; a
simple "avoid yesterday's index" draw is enough). Use a seeded/injectable RNG so
tests are deterministic.

### 3. Time jitter ±10 minutes

Each scheduled invitation fires at the user's chosen time plus a uniform random
offset in [-10, +10] minutes, re-drawn per day (same injectable RNG). Never
schedule before 06:00 or after 23:00 local regardless of jitter — clamp.

### 4. Exponential backoff on absence (this IS the decoupled semantics)

The pet does not chase. Backoff ladder driven by consecutive days the app was
NOT opened, evaluated when scheduling:

- 0–2 days unopened: invitation daily (normal).
- 3–6 days unopened: every 2nd day.
- 7–13 days unopened: every 4th day.
- 14+ days unopened: weekly.
- Any app open resets the ladder to normal immediately (rescheduling already
  happens on resume via `_refreshNotificationSchedule`).

Signal: derive "last opened day" from what the app already persists —
`AppState` has day-rollover data; if nothing usable exists, add
`lastOpenedDay` (a local-day string) to AppState with a v-bump migration test
(red line: existing users keep all data; a missing field must default safely
so behaviour for an upgrading user is "normal cadence").

Per-task reminders: do NOT redesign, but they participate in the same absence
check — if the user hasn't opened for 7+ days, per-task reminders pause
entirely (resume on next open). A reminder for a task list the user hasn't
seen in a week is pure debt.

### 5. Respect the existing 32-slot budget

Scheduling window shares ~32 pending-notification slots with task reminders
(iOS 64-limit halved in practice — see existing code's limit handling). The
backoff REDUCES scheduled count; make sure the window logic still fills
correctly at each ladder tier (e.g. weekly tier schedules ~4 invitations over
28 days, not 1).

## Tests (all deterministic via injected RNG/clock)

- Template pool: no two consecutive scheduled days share an index; all 12
  reachable over a long horizon.
- Jitter: offsets within ±10 min; clamped to [06:00, 23:00].
- Backoff: each tier's cadence exact (days 0,1,2 daily; day 3 → skip to day 4,
  etc.); reset-on-open restores daily; per-task reminders absent at 7+ days.
- Migration: existing state without the new field loads with normal cadence and
  loses nothing (follow the pattern of app_state_migration_test).
- Copy lint test: every template title+body contains none of the forbidden
  substrings ("waiting for you", "miss you", "come back", "don't forget",
  "come home", "see you").

## Acceptance

- `flutter analyze` clean; full suite green **3× consecutively** (parallel-flake
  discipline; timing assertions follow the runAsync-synchronous pattern noted in
  docs/IMPLEMENTATION-NOTES.md).
- No UI changes. No new screens. English copy only.
- **Do NOT commit or push. Leave the working tree for review.**
- Work ONLY in this worktree (`~/Projects/apps/pettodo-w1`). Do not touch the
  main checkout.

## Known gotchas (docs/IMPLEMENTATION-NOTES.md — read §Notifications first)

- flutter_test zone traps: stores/plugins constructed inside runAsync.
- The notification plugin must never be able to prevent app startup (6c886af
  lesson) — keep all new logic failure-tolerant.
- JDK pinned via `flutter config --jdk-dir`; Android build not required for
  this task (logic + tests only), iOS sim build IS required to prove it boots.

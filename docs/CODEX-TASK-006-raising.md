# Task 006 — 养成系统 2.0 (Play Depth)

> Status: QUEUED — start after Task 005 (1a design skin) is merged. UI must use the 005 theme layer.
> Driver (2026-07-20, David): founder self-test verdict on v1 —「功能太少根本没法玩」. The companion loop needs depth. Battlefield unchanged: emotional companion, NOT efficiency todo.

## HARD RED LINE (unchanged, applies to every feature below)

Pet is NEVER harmed/sad/degraded by user inaction. No decay, no hunger damage, no streaks, no guilt. Everything below only ADDS positive states; absence of interaction = calm neutral, never negative.

## Features

1. **Growth stages**: 幼年 puppy → 少年 junior → 成年 adult, driven by `lifetimeCompletions` (thresholds 0 / 40 / 120 — tune in one constants file). Visual: stage badge + scale/frame treatment via theme layer (no new sprite art required; architecture must allow per-stage sprite folders later).
2. **Treat economy**: each task completion drops 1 treat (小鱼干/肉骨头, per-pet treat type in manifest). Treats accumulate (no cap, no expiry). "Feed" action: tap treat button → feeding moment (reuse `jumping`/`waving` rows + particle), pet status line changes for the rest of the day (「吃饱饱的 Choco 心情很好」). Feeding is NEVER required — an un-fed pet is simply calm.
3. **Pet touch interaction**: tapping the pet itself → reaction: look-toward-tap using look-row 16-direction frames, then a random affectionate line (pool of ≥12, pet-voice). Long-press → 蹭你 (`waving` + heart particle). Zero cost, unlimited.
4. **Mood & daily schedule**: pet has its own life driven by time-of-day: morning stretch (waving), midday nap (waiting row + zzz), afternoon idle, evening by-the-window (look rows). Status line follows. Same schedule table the iOS widget (Task 002) will read — put it in domain layer.
5. **Decor placement + collection**: unlocked decor items render in the home scene at fixed slots; unlock curve extended: 5/15/30/50/80/120 (6 items; new items defined in manifest with emoji placeholder until designer art arrives). Collection page (from Settings or home entry): grid of unlocked + silhouette of locked WITHOUT progress bars or "differ N times" pressure copy — pure gallery. (Keep the existing gentle "下一个解锁还差 N 次" line in Settings only.)
6. **Little Theater**: implement the full 3/3 celebration per `docs/design/rendered/option-2b.html` (LITTLE THEATER overlay, "Thank you, {petName}" button) — if 005 already implemented it, extend with treat-drop bonus (+2 treats on 3/3).

## Data & events

- Extend AppState (versioned migration from v1 JSON — existing users' state must load cleanly): treats, fedToday(date-keyed), stage derived not stored.
- New events: `treat_feed`, `pet_touch`, `stage_up` in the JSONL log.
- Unit tests: stage thresholds edges, treat drop/spend, fedToday day-boundary reset (silent), state migration v1→v2.

## Acceptance

- analyze clean / all tests green / iOS sim build / Android apk build (JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home).
- Sim walkthrough: touch pet → look reaction + line; complete task → treat drops; feed → moment + status change; collection page renders; all红线 hold.
- One atomic diff, no commit. Append to docs/IMPLEMENTATION-NOTES.md.

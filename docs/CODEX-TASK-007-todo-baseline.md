# Task 007 — Todo 及格线 (Tool Usability Baseline)

> Status: QUEUED — start after Task 006. David's ruling (D17, 2026-07-20): baseline list ONLY — explicitly NOT projects/subtasks/priorities/kanban/calendar/collaboration. Battlefield stays emotional-companion.

## Features

1. **Flexible task count**: 1–7 daily tasks (3 remains the onboarding suggestion). Add/remove/edit from Home (edit mode) and Settings. Domain invariant "exactly 3" is removed; migration keeps existing 3.
2. **Two task kinds**: `daily` (recurring, resets at local midnight — existing behavior) and `oneOff` (stays until completed, then archived to history; NO due date). One quick-add entry on Home (「记一件事」) defaulting to oneOff.
3. **Per-task reminder** (optional): a local time per task; fires as an additional local notification in pet voice referencing the task title (「Choco 提醒你：该喝水啦～」). Same permission semantics as the daily invitation; per-task toggle. Cap total scheduled notifications sensibly (reuse 32-slot window strategy).
4. **One-line note per task**: optional, shown under title in smaller type, editable where titles are edited.
5. **Positive history**: a simple view (entry from Settings or Home): per-week counts —「这周你和 {pet} 一起完成了 N 件事」+ list of completed items by day. NO streaks, NO gaps highlighted, missed days simply absent, no red, no zero-shaming (a week with 0 just isn't listed).

## Red lines (unchanged)

Silent rollover for daily tasks; oneOff tasks never show age/overdue; no counts of undone; reminders are invitations, never repeat-nag (one fire per task per day max); denied permission → never re-ask.

## Data & events

- AppState migration v2→v3: task list becomes list of {id, title, kind, note?, reminder?, completedToday/completedAt}. Preserve lifetimeCompletions & unlocks. Treat drops (006) apply to BOTH kinds.
- Events: `task_add`, `task_remove`, `task_edit`, `oneoff_complete` added to JSONL.
- Unit tests: migration v2→v3, oneOff lifecycle, daily reset unaffected by oneOff, reminder scheduling windows, history aggregation by local week.

## Acceptance

- analyze clean / tests green / both builds (JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home).
- Sim walkthrough: add 5th task, add oneOff via quick-add, set a reminder, complete oneOff → treat drops + appears in history; day rollover keeps oneOff, resets daily.
- One atomic diff, no commit. Append to docs/IMPLEMENTATION-NOTES.md.

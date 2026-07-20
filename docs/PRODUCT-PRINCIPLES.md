# PetTodo Product Principles

## ADHD-first (constitution, decided 2026-07-20)

PetTodo is built for ADHD / mild-ADHD users. **Every feature must trace to a
specific ADHD problem it solves. If the mapping can't be stated, the feature
doesn't get built.** Every task card states its mapping in one line; reviews
verify it.

### Existing feature mappings

| Feature | ADHD problem it solves |
|---|---|
| Task cap 1–7 (soft copy: "Seven little things are plenty for now") | Working-memory overload & choice paralysis — a long list becomes a wall the user stops opening |
| One-off tasks, 2-step quick capture (tap + → type → Done), title-only required | Fleeting-thought loss — thoughts drop out of working memory in seconds; capture friction must be near zero |
| Per-task reminder, pet-voice invitation, hard max one fire per task per day | Time blindness — but repeated pings trigger avoidance, so the once-per-day cap is inviolable |
| Positive-only history ("You and {pet} did N things together"), days without completions simply don't appear | Rejection-sensitivity — broken streaks are the #1 reason ADHD users abandon habit apps; no streaks, no gaps, no zeros |
| Non-goals: projects, subtasks, priorities, kanban, calendar, collaboration | Executive-function tax — every organizational layer is overhead that drives abandonment |
| Pet never punished, no failure states, silent midnight rollover with no yesterday trace | Shame spiral — failure → shame → avoidance kills tool use; the pet only ever radiates warmth |
| One-off tasks never show age or overdue markers | Overdue badges are shame accumulators; a captured thought stays fresh until acted on or removed |

### Red lines (from the approved design doc, restated)

1. The pet is NEVER hurt, sad, or degraded by user inactivity. Zero punishment.
2. All completion feedback is warmth-only; missing everything produces silence, not guilt.
3. Notifications are invitations from the pet, never nags; denied permission is never re-asked.

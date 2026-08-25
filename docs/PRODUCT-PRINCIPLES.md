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

## Research-hardened rules (2026-08-13)

Derived from two first-hand Reddit research reports collected on 2026-08-13:
the **App** report (why ADHD users abandon productivity tools, r/ADHD,
r/adhdwomen, r/ADHD_Programmers) and the **Ppl** report (symptoms and daily life,
r/ADHD, r/adhdwomen). Citations below read `App-X` / `Ppl-X` against those files;
both are linked from `PLAN-2026-08-13-post-research.md`. These rules exist to stop
settled questions from being reopened by future feature discussions.

### Absence semantics — DECIDED (⚖️2026-08-25, David)

> **Status: settled.** Option B — the pet lives its own good day — with the
> "presence without a request" refinement folded in: the pet may still speak
> (notifications stay), but only ever about itself. This answers the
> strongest counter-evidence (the widget bird that "speaks up") without
> reintroducing the guilt debt: our pet reaches out, it just never asks.

**The rule:** the pet's wellbeing is never a function of user presence. The
pet lives its own good day — sunning itself, napping, watching the window, on
its own schedule. Opening the app is *joining* that day, never *compensating*
for a missed one; the pet never waits, misses the user, or summons them back.
Notification copy would therefore report the pet's own day and never request
presence, excluding "waiting for you", "misses you", "come back", "don't
forget", and any other formulation whose subject is the user's absence.

**For it (App-D1):** zero punishment stops the *app* inflicting negative
feedback but does not stop users projecting guilt onto an anthropomorphic
character, and that projected guilt is the direct abandonment trigger ("I'd
rather not open the app than see a sad bird"). Decoupling removes the debt at
source — nothing is owed to a pet that was fine anyway.

**Against it (Lit-, Rev-):** the strongest single piece of user evidence in the
review corpus is a five-star account of a widget pet speaking up on a day the
user had given up ("my bird telling me we can fix this"), which is the opposite
of a pet that never reaches out. Withdrawal of contact is also ambiguous by
construction, and rejection sensitivity is defined as readily perceiving
intentional rejection in ambiguous behaviour, so silence may itself be read as
abandonment.

**A middle option exists** and has not been costed: the pet speaks, but only
about itself — presence without a request.

### Reward rules — DECIDED (⚖️2026-08-25, David)

| Rule | ADHD problem it answers |
|---|---|
| **No daily pet-tasking.** The app never asks the user to assign, plan or queue tasks *for* the pet on a per-day basis. | App-D6: daily pet-tasking is itself a maintenance burden — the exact executive-function tax that kills tool use; the cited user spent their last two months going through the motions purely to collect daily rewards, then quit |
| **No completion-for-reward strong coupling.** No mechanic where finishing tasks unlocks pet content (adventures, quests, gated fun). | App-D2: rewards tied to claimed completions produce self-deception — users log tasks they never did to feed the pet, know they are doing it, and accumulate shame; data credibility and the user's self-image collapse together |

The existing treat economy stays as-is and is explicitly **weak-coupled**: treats
drop on completion, there are no combos, no progress bars, no deadlines, and
spending them is optional. Weak coupling is permitted; strong coupling is not.

> **Status: settled as written** — both rules are constitution now, chosen
> knowing the literature argues the second is over-cautious. The undermining effect is confined to expected,
> tangible, task-contingent rewards, while positive feedback *enhances*
> free-choice persistence ([Deci et al. 1999](https://doi.org/10.1037/0033-2909.125.6.627)),
> and the ADHD reinforcement literature finds contingent immediate
> reinforcement helps this population somewhat *more* than controls
> ([Luman et al. 2005](https://doi.org/10.1016/j.cpr.2004.11.001)). The
> proposal is also internally inconsistent: treats and decoration unlocks are
> themselves expected task-contingent rewards, so an argument that bans
> unlocks indicts the shipped reward loop too.

### Copy and feature rules

| Rule | ADHD problem it answers |
|---|---|
| **Tone double-bind.** Copy avoids BOTH the indulgence side ("it's okay", "no pressure", "you poor thing" framings that read as a free pass) AND the drill-sergeant/hustle side ("you've got this", "just do it", "let's crush today"). House voice: the pet shares its own concrete little day; it neither judges nor absolves. | Ppl-E4: the community is split down the middle — anything sounding like a permission slip for failure is rejected by half of it, anything sounding like self-discipline pep talk is read as humiliation by the other half. The middle road is not a style preference, it is a hard constraint |
| **Anti-organizing.** No feature may require the user to categorize, file, archive, or tidy. Nothing may be hidden away for the sake of neatness. | Ppl-H6 and App-C2: sorting is the symptom's opposite, not its cure. Triage is the reason people stop writing things down at all (App-C1), and setup-stage organizing decisions are where users quit before ever using the tool. Combined with "out of sight is out of existence" (Ppl-A3), any "tuck it away, it's tidier" design is a negative for this population |
| **Terminology.** Never present "RSD" as established medical fact in documentation or user-facing copy. Use "rejection sensitivity" / "emotional dysregulation". | Ppl-C5: r/ADHD's own moderation states RSD is not recognised by any medical authority, is absent from DSM and ICD, and lacks peer-reviewed support. Using it as fact costs credibility with exactly the audience being served |

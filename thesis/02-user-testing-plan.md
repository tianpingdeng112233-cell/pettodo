# PetTodo — User Testing Plan

*Final year project, University of Manchester. Drafted 2026-08-13 against `main`
at `f05cde8`. Companion to `thesis/01-midterm-report-draft.md`, section 5.*

## 0. Questions for the school — do this first

This section is first because it is the longest-lead-time item in the project.
Recruitment cannot begin until it is resolved, and the 14-day window plus
analysis has to fit before the report deadline. Nothing else here should start
before these answers are in hand. The checklist for the supervisor and, if she
directs, the department's ethics contact:

1. **Is ethics approval required at all** for a final-year project recruiting
   adults who self-report ADHD? Working assumption: yes. Participants are not a
   formally vulnerable group — adults giving informed consent, not patients, not
   minors, no diagnosis sought or verified — but recruitment is on the basis of a
   self-declared neurodevelopmental condition and the app touches daily
   functioning and self-reported guilt. That is vulnerable-adjacent, so assume
   review is needed.
2. **What is the turnaround?** In calendar weeks, and whether a committee meets
   on a cycle or there is a submission cut-off. This number determines the entire
   project schedule.
3. **Is there a lighter-touch route** for low-risk student projects — self-
   assessment or tutor sign-off rather than full committee — and what evidence
   does it need?
4. **Is there a standard consent form and participant information sheet
   template?** Using the department's wording beats writing one and having it
   rejected.
5. **What are the data-handling requirements** where all data stays on the
   participant's device and reaches the researcher only if they choose to export
   and send it? Is a data management plan required, where may exported files be
   stored, and when must they be destroyed?
6. **Does recruiting from the researcher's personal network change anything?**
   Perceived obligation to a friend is a real consent pressure.
7. **What must be disclosed about withdrawal**, and may a participant withdraw
   exported data after sending it?

If approval is needed and slow, the fallback is a structured self-evaluation with
fewer participants under whatever the school permits, reporting the constraint
honestly rather than quietly proceeding. **Ask before recruiting anyone.**

## 1. Purpose and hypotheses

The **primary** question is retention: does an external-anchor mechanism keep
ADHD-leaning users returning where reminder-based tools do not? The **secondary**
question matters more for the design — whether the central premise survives
contact with real users, namely that a pet built from the user's *own* animal
deepens attachment without importing guilt. That premise has a documented failure
mode: users of comparable applications report being unable to open the app
because they cannot face the character. If participants report guilt, dread, or
an uncanny reaction to their own animal rendered, the premise is falsified, and
that finding outweighs any retention number.

## 2. Participants and recruitment

Five to ten seed participants, matching the product's own Phase 2 plan: adults
who self-report ADHD or ADHD-like executive-function difficulty *and* who own a
pet, since the hatch loop requires a photograph of a real animal. Self-report is
sufficient; no diagnosis is requested, recorded, or verified.

Recruitment is **through the researcher's personal network only** — friends,
family, and people who volunteer after hearing about the project directly. There
will be **no posting in ADHD communities, covert or otherwise**. This is not
squeamishness: the App research report documents r/adhdwomen moderators publicly
naming six products for stealth marketing, with the top comment (1,139 upvotes)
demanding the full list and another (518 upvotes) calling the practice preying on
disabled people; affiliate links are banned outright. Recruitment that looked
like a product doing community research would be identified as such — an ethical
failure and reputationally terminal. If more participants are needed later, the
route is open, identified recruitment with moderator permission, or nothing.

## 3. Design

Fourteen days of ordinary use, starting once onboarding is complete and the
participant's own pet has been generated and imported. No usage is prescribed;
stopping is a valid and informative result, and participants are told explicitly
that abandoning the app is a normal outcome the researcher wants to hear about
rather than be spared.

**Primary metric — 14-day retention, bar >50%**, where a participant counts as
retained if the app was opened on at least one of days 12–14. The bar is the
standard the target community itself set out, on the reasoning that early reviews
are worthless because ADHD reviewers are novelty-seeking by disposition and only
two-week retention convinces. Adopting the population's own criterion rather than
a flattering invented one is deliberate.

**Secondary measures**, all from the local event log: completions per active day,
daily-to-one-off ratio, interval distribution between opens, and whether opens
cluster around notification times or occur independently — the last being the
closest available proxy for the anchor mechanism working as designed.

**Red-light qualitative monitoring.** Throughout, the researcher watches for the
"premise 2" red light: guilt toward the pet, dread of opening the app, avoidance
framed in terms of the animal, or an uncanny or distressing reaction to seeing
their own pet rendered — particularly acute if the real animal is elderly or has
since died, which must be considered before inviting any given participant. A
single credible red-light report is a serious finding written up as such, not
averaged away against retention figures.

## 4. Instruments

A **short weekly questionnaire** at day 7 and day 14, deliberately brief because
the same research shows length itself drives attrition in this population. Six
items: when the app was last opened and what prompted it; whether any
notification was noticed and how it read; one free-text item on how the pet feels
to have around, worded neutrally enough to catch warmth and guilt without leading
toward either; whether anything was recorded as done that was not done, asked
without judgement because falsification is expected behaviour rather than a
participant failing; whether anything was irritating or embarrassing; and whether
they expect to keep using it.

**Local data export.** The app already writes a newline-delimited JSON event log
and exports it through the system share sheet. There is no server and no
analytics service, so the export is the only data channel and is entirely
user-initiated. Exports are requested at day 14 only.

**Exit conversation**, 15–20 minutes, optional, semi-structured on the same
themes.

## 5. Consent and data handling

Participants receive a plain-language information sheet and give written consent
before installation, using the department's template if one exists (§0.4). It
states: what the app does; that all data stays on their own device and nothing is
transmitted automatically; that the researcher receives only what they choose to
export and send; that photographs of their pet generate the sprite and are not
published; that they may stop at any time without giving a reason; and how to
withdraw data after sending it. Exported logs are pseudonymised on receipt
(participant code, not name) and contain task titles that participants are warned
may be personal, with an explicit instruction that they may delete any line
before sending. Nothing is published that could identify a participant or their
animal.

## 6. Analysis and the heterogeneity caveat

With n between five and ten, no inferential statistics are appropriate; retention
is reported as a raw count with each trajectory described individually. This is
the correct treatment on the evidence, not a concession to sample size:
practitioner estimates put the transfer rate of any single-mechanism ADHD
intervention at 5–10%, because ADHD is a symptomatic rather than aetiological
diagnosis with highly dispersed underlying causes — hence the field's own maxim
that having met one person with ADHD means having met one person with ADHD.
Divergent outcomes are therefore the **expected** result, not noise, and uniform
success across ten participants should be regarded as suspect.

The analysis must therefore separate three readings, and the instruments above
are chosen to make that separation possible:

| Reading | What it looks like in the data |
|---|---|
| **The mechanism is ineffective** | Participant engages with the pet, reports liking it, and still does not act — opens are decorative, completions do not rise, "I looked at it and did nothing" |
| **Wrong subtype for this mechanism** | Participant never forms the attachment at all, is indifferent to the pet, and the app is simply a plain to-do list to them — a different intervention is indicated, not a redesign of this one |
| **Premise failure (red light)** | Attachment forms and turns into debt — guilt, avoidance, dread of opening; this invalidates the design rather than the fit |

Conclusions will be written as design implications for a named subtype, not as
generalisations about ADHD.

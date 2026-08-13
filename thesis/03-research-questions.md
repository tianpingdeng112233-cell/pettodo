# 科研侧问题清单 — 给 Claude Science 的 prompt

用法:下面 `---` 之间的整段英文可以直接复制粘贴。答案回来后归档到本文件末尾的
「回收区」,并替换 `01-midterm-report-draft.md` 里的 `[TODO: academic reference
needed]` 标记。**任何未经核实的引用不得进正文**。

---

I am building a final-year Computer Science project (University of Manchester)
and need the research literature checked before I commit to design decisions and
before I write the literature review. I need verifiable sources, not plausible
ones.

**The product.** PetTodo is an offline mobile app (Flutter, iOS + Android) for
adults with ADHD or ADHD-like executive-function difficulty. It pairs a
deliberately minimal to-do list (1–7 active items, no projects, subtasks,
priorities, boards or calendar) with a virtual pet generated from a photograph of
the user's *own* real animal. Completing a task produces warmth-only feedback:
the pet reacts happily, treats drop, decorations unlock. There are no streaks, no
failure states, no punishment, and no negative pet reactions — ever. Missing
everything produces silence, not guilt. A single daily notification is written in
the pet's voice. All data stays on the device; there is no account and no server.

**The design thesis I need tested.** Gentle reminders do not initiate action in
this population, whereas *external anchors* — dependants, animals, other people —
do. So the pet is not decoration; it is meant to be the digitisation of a
mechanism this population already uses. The counter-risk is that anthropomorphic
characters generate guilt debt and become the direct cause of abandonment.

Please answer the questions below. **Group A can overturn my design, so treat it
as adversarial review, not support-gathering.**

## Group A — findings that could invalidate the design

A1. When users form attachment to an anthropomorphic virtual character in a
self-care or productivity context, is there evidence that lapses produce guilt,
avoidance, or app abandonment? This is my single biggest risk: my own user
research found people reporting they would rather not open an app than see a
neglected virtual character. Is this documented in the literature, and does
removing all punitive feedback actually remove the effect, or does user-projected
guilt persist regardless of what the system does?

A2. What is the efficacy evidence for virtual-pet, care-taking or companion
mechanics in behaviour-change or productivity apps, specifically for **adults**
with ADHD? Distinguish engagement metrics from actual behaviour change.

A3. Is there evidence that external, concrete anchors — caring for an animal, a
dependant, or the presence of another person ("body doubling") — improve task
initiation in ADHD, relative to reminder- or planning-based interventions? This
is the mechanistic claim my whole product rests on. If the evidence is weak or
absent, say so plainly.

A4. Does reward contingency undermine intrinsic motivation (overjustification),
and does this operate differently in ADHD given altered reward sensitivity and
delay aversion? I have banned mechanics where completing tasks unlocks pet
content, on the basis that users self-report falsifying completions to earn
rewards. Is that ban supported, over-cautious, or misguided?

A5. What is the evidence on streaks, loss-framing and punishment mechanics in
habit apps for populations with high rejection sensitivity or emotional
dysregulation? I have banned all of them.

## Group B — support for decisions already made

B1. Executive function in adult ADHD: working memory as a core mechanism,
prospective memory failure, and the resulting "the tool itself becomes a task to
maintain" problem. I need the strongest one or two sources for a literature
review, not a survey.

B2. Time blindness / temporal discounting / delay aversion in ADHD.

B3. Choice overload and task-list length. Is there evidence for an upper bound on
visible items before a list becomes avoidant rather than useful? My cap is 1–7
and is currently justified only by user reports.

B4. Notification habituation: does varying wording and timing measurably slow
habituation compared to fixed, repeating notifications? I am implementing
randomised copy from a pool, ±10 minutes of jitter, and exponential back-off
after repeated non-engagement. Is there evidence for or against each of the
three?

B5. Self-determination theory (autonomy/competence/relatedness) applied to
digital interventions for ADHD — is it a defensible framing for a companion-based
design, or is it applied loosely in this literature?

## Group C — claims I must verify or discard

C1. A community explanation, attributed to someone identifying as a therapist,
says that when a task becomes urgent the drive shifts "from the prefrontal cortex
to the amygdala", which is why urgency initiates action in ADHD when gentle
reminders do not. Is there a defensible neurobiological account of urgency-driven
initiation in ADHD, and is this framing accurate, an oversimplification, or
wrong? I need to either corroborate it or replace it.

C2. Practitioners in my source material estimate that any single-mechanism ADHD
intervention transfers to only 5–10% of the population, because ADHD is a
symptomatic rather than aetiological diagnosis. Is there published support for a
figure of this kind, or for the heterogeneity claim behind it? I am using it to
justify expecting divergent outcomes in a small evaluation.

C3. What is the actual academic status of "Rejection Sensitive Dysphoria"? The
r/ADHD moderation states it is not recognised by any medical authority, absent
from DSM and ICD, and lacks peer-reviewed support. Is that accurate? What are the
correct terms and the evidence base for the underlying phenomenon?

C4. What is a realistic retention benchmark for mental-health and behaviour-change
apps? My target population itself proposed ">50% still using it at two weeks" as
the only convincing standard. How does that compare to published retention
figures for this category — is it a demanding bar, a trivial one, or unmeasurably
optimistic?

C5. My supervisor forwarded praise for the concept from a specialist in **early
years special needs education**, who suggested earning pet treats by finishing
tasks within a set time, and noted that some children find abstract timers
stressful but respond well to a *concrete relative* anchor ("can we finish this
before they finish making your lunch"). Two questions: how well do ADHD
intervention findings transfer from children to adults, and is there evidence on
relative/concrete time anchors versus abstract countdown timers?

C6. Is there evidence on whether a personally meaningful avatar (the user's own
pet) produces stronger engagement than a generic one — and any evidence on
uncanny or distressing responses to stylised renderings of a real, personally
significant animal, including a deceased one?

## How to answer

For each question: a one-sentence conclusion first, then the evidence strength
(meta-analysis / systematic review / RCT / observational / expert opinion /
none found), then citations I can verify — authors, year, venue, and DOI or a
stable link.

Rules I need you to follow strictly:
- If you cannot find credible evidence, say "no credible evidence found" rather
  than offering weak or tangential work. An empty answer is more useful to me
  than a padded one.
- Do not fabricate citations, and do not cite anything you have not actually
  located. I will check every one.
- Flag explicitly any evidence that **contradicts** my design decisions. Those
  are the most valuable answers here.
- Distinguish adult from child samples, and clinical from subclinical or
  self-identified samples — my users self-report and are not diagnosed.
- Note where findings come from populations that do not match mine.
- Where the literature is genuinely contested, say so rather than picking a side.

---

## 回收区(答案归档)

<!-- 答案回来后贴在这里,标注日期与来源。核实过 DOI 的才能进正文。 -->

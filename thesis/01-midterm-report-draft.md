# PetTodo — Progress Report

---

## Abstract

PetTodo is a dual-platform (iOS and Android) mobile application pairing a
deliberately minimal to-do list with a virtual pet generated from a photograph
of the user's own animal, aimed at adults with ADHD or ADHD-like
executive-function difficulty. Its design thesis is that gentle reminders do
not initiate action in this population, whereas external anchors — dependants,
animals, other people — might, so the pet digitises a mechanism the population
already uses. I tested that thesis against four bodies of evidence gathered for
this report, and the most consequential finding is adverse to it: the anchor
mechanism turns out to be the least evidenced proposition in the design, while
the reminder-and-planning approach it rejects has controlled effects in
diagnosed ADHD samples. The safety architecture fared better, though the
assumption that removing punishment removes guilt is contradicted by studies of
trackers with no character and no failure state at all. At mid-term the core
loop is functionally complete on both platforms with 47 automated tests passing;
the remaining work is an evaluation designed to test the mechanism rather than
assume it.

---

## 1. Introduction

### 1.1 Context and motivation

Conventional task-management software assumes the user can maintain the system
it provides. For adults with ADHD this inverts the problem: the executive
function needed to keep a productivity tool current is precisely what is
impaired. The specific capacity involved is prospective memory — remembering to
carry out an intention at the right moment — and it fails asymmetrically: in a
case-control experiment, 25 adults with diagnosed ADHD showed a large
impairment in *time-based* prospective memory while performing comparably to
matched controls on *event-based* tasks
([Altgassen, Kretschmer & Kliegel 2014](https://doi.org/10.1177/1087054712445484),
*Journal of Attention Disorders*). The population is also deeply heterogeneous:
across six neuropsychological domains, no single deficit is present in more
than a minority of diagnosed individuals — 18.1% to 36.1% depending on domain
([Coghill et al. 2014](https://doi.org/10.1017/s0033291713002547),
*Psychological Medicine*). Any mechanism a tool builds will therefore reach a
subgroup, not the population — including the reminder mechanisms this project
set out to improve upon.

The motivating observation is that the interventions this population itself
reports as working are concrete and external — a child, a dog that must be
walked, an alarm clock placed across the room — rather than motivational
messaging. PetTodo asks whether that observation survives being built: whether
a virtual pet derived from the user's own animal can serve as an external
anchor for small daily tasks.

### 1.2 Aims and objectives

Build and evaluate a to-do application whose engagement mechanism is an
external anchor rather than a reminder, without importing the guilt that has
caused comparable applications to be abandoned. Objectives: (i) a dual-platform
core loop working entirely offline, with no account and no server; (ii) a pet
generated from the user's *own* animal, on the hypothesis that attachment to a
real, recognisable companion exceeds attachment to a generic avatar;
(iii) safety red lines — no punishment, no streaks, no failure states —
enforced structurally rather than by discipline; (iv) an evaluation against a
retention criterion, with the criterion itself examined rather than assumed.

### 1.3 Background

#### 1.3.1 The problem: abandonment, not absence of features

The category's failure mode is documented best by its own users. Reading
high-engagement threads across r/ADHD, r/adhdwomen and r/ADHD_Programmers —
including a 4,625-upvote account of 500 days spent trialling 36 productivity
applications — three patterns recur. Feature completeness does not solve the
problem: the highest-voted example describes a user who built himself an
application that ingested his email, prioritised automatically and contacted
him each morning, and still did not use it; friction is not the barrier,
initiation is. Second, maintaining the tool is itself an executive-function
task, so the tool decays exactly when the user does. Third, the community
proposes its own evaluation standard: early reviews are worthless because ADHD
reviewers are novelty-seeking by disposition, and only two-week retention
convinces. A serial abandoner's description supplies the phrase this project
now designs against: an app that "feels like my disappointed mother", where the
user feels "guilty about the app I downloaded to stop feeling guilty about
tasks" — a state commenters name a *shame reminder*.

#### 1.3.2 Survey of existing systems

I surveyed the four dominant applications in this space through 4,754 store
reviews collected for this report (method and sampling caveats in §2.2), plus
their public store metadata.

**Finch** (virtual bird plus self-care tasks; 739K App Store ratings at 4.9★,
10M+ Play installs) is the category leader and the reference product for the
pet mechanism. Emotional-bond language ("my birb", "companion", "attached")
appears unprompted in 29% of its recent Apple reviews, against 9–13% for the
other three — the clearest external evidence that the pet mechanism does
something the others do not. Its user-reported failure modes are equally
instructive: guilt on lapse severe enough that users stop opening the app;
falsified completions to earn pet rewards, recognised as self-deception while
it happens; an aesthetic that adults repeatedly call infantile; and — its
top-voted Android complaint — data loss, with multi-year pets wiped and users
explicitly requesting a manual backup button the product does not provide. One
detailed user account also locates the mechanism's effective range: the pet
reward does not motivate large goals ("being rewarded by buying clothes for a
virtual bird isn't enough motivation"), but works for small daily maintenance —
finishing a bottle of water, stretching, taking medication — and the app is
opened *to see the pet*, with reminders seen incidentally.

**Tiimo** (visual daily planner; Apple "app of the year" laurels) shows a
severe divergence between its 4.6★ cumulative rating and its recent reviews,
28.6% of which are one-star; its highest-concentration complaint cluster is
notifications, and it barely exists on Android. **Habitica** (RPG-style
gamification, 5M+ Play installs) demonstrates the punishment problem this
project's red lines answer — its angriest reviews concern losing levels to a
boss fight — and a years-long, still-open wound around Android notifications
failing under battery management or arriving in overwhelming batches.
**Numo** (positions itself as the non-infantile ADHD app) holds the positioning
this project also targets but is burning it: 29% of its reviews concern billing
disputes, and its Android rating has collapsed to 3.29★. A newer cluster of
quest-style apps (Hyper, TaskHero, LifeUp) competes for the same users with
"levelling up, not being told what to do".

Three design consequences: the pet-bond mechanism is validated and its ceiling
untouched; data loss is existential for an emotional product and *worse* for
PetTodo, whose pet is irreplaceable and whose storage is local-only; and
subscription dark patterns are a category-wide trust failure that a competitor
can differentiate against simply by not committing them.

#### 1.3.3 The evidence on the design premises

Before this report I treated the anchor mechanism as established and the safety
rules as obviously sufficient. I ran a structured literature search across
sixteen questions to check both (method in §2.2); it changed my position on
each, and the report states the revised positions rather than defending the
original ones.

**The anchor mechanism is not an established finding.** The only controlled
test of "body doubling" — working alongside another person — was null on 26
participants ([Schuenke et al. 2025](https://doi.org/10.1145/3663547.3759743)),
and the broader social-facilitation meta-analysis puts mere presence at 0.3–3%
of variance while finding it *impairs* complex-task performance
([Bond & Titus 1983](https://doi.org/10.1037/0033-2909.94.2.265)). Animal care
has never been tested as a task-initiation aid in ADHD adults. Nothing I
retrieved supports the chain *human presence helps → animal responsibility
helps → a photo-derived virtual animal helps*. PetTodo therefore **tests** a
mechanism rather than implementing a demonstrated one, and this report claims
accordingly.

**The rejected comparator works.** If-then implementation planning improves
inhibition, shifting and distraction resistance in children with diagnosed ADHD
([Gawrilow & Gollwitzer 2008](https://doi.org/10.1007/s10608-007-9150-1)), on
top of a large general-population meta-analysis
([Gollwitzer & Sheeran 2006](https://doi.org/10.1016/s0065-2601%2806%2938002-1)).
"Reminders do not work, anchors do" inverts the evidential ordering.

**Removing punishment does not remove guilt.** Guilt is a documented
post-abandonment state in self-trackers with no character, no failure state and
no punitive feedback — 16.2% of activity-tracker users
([Epstein et al. 2016](https://doi.org/10.1145/2858036.2858045)) — because it
is generated by the user's own appraisal. Anthropomorphic framing independently
raises the felt cost of abandoning an entity
([Chandler & Schwarz 2010](https://doi.org/10.1016/j.jcps.2009.12.008)), and an
analysis of 582 r/Replika posts found harms mediated by role-taking: users felt
the character had needs they were obliged to attend to
([Laestadius et al. 2024](https://doi.org/10.1177/14614448221142007)). The
zero-punishment red line is necessary but insufficient; the *shame reminder*
finding says the same from the user's side.

**The one experiment that manipulated pet feedback valence found warmth-only
inert.** Adolescents whose virtual pet gave both positive and negative feedback
were roughly twice as likely to eat breakfast; the positive-only pet did not
beat control ([Byrne et al. 2012](https://doi.org/10.1080/17482798.2011.633410)).
The sample is adolescent, the outcome is breakfast, and guilt was not measured —
but it is the closest existing test of this project's central safety rule, and
it is not reassuring. I retain the rule as an ethical commitment; the
evaluation must be able to see whether warmth-only is *sufficient*.

**Three claims I had been repeating are withdrawn.** The
"prefrontal-to-amygdala switch" account of urgency-driven initiation does not
survive contact with its sources — the finding concerns acute uncontrollable
stress producing *impairment*, largely in animals
([Arnsten 2015](https://doi.org/10.1038/nn.4087)), while ADHD prefrontal
regions are *under*-active. The "5–10% transfer rate" for single-mechanism ADHD
interventions does not exist in the literature and is demoted to attributed
practitioner opinion. And the 1–7 task cap cannot cite Miller: "seven plus or
minus two" concerns immediate memory span, and Cowan describes the seven as a
rhetorical device ([Cowan 2001](https://doi.org/10.1017/s0140525x01003922)).
The cap is instead defended by the effective-range observation in §1.3.2: small
daily maintenance is where the pet mechanism works at all.

**What the evidence does support.** Warmth-only *reinforcement* has a direct
ADHD result: on an incentive go/no-go task, participants with ADHD gained more
from social reward — positive facial expressions — than controls
([Kohls et al. 2009](https://doi.org/10.1186/1744-9081-5-20)). And the
event-based cue is the best-grounded interaction choice available, per the
prospective-memory dissociation in §1.1. Notably, this supports the cue type
independently proposed by the early-years special-needs specialist whose
feedback my supervisor forwarded — a concrete relative anchor ("can we finish
this before they finish making your lunch") — rather than the clock-triggered
daily prompt I currently implement.

---

## 2. Methodology

### 2.1 Engineering method

**Platform.** I chose Flutter over two native codebases. The justification is scope: evaluation needs real users on
whatever handset they own, and a solo project cannot maintain two native
implementations to that standard. The cost is accepted deliberately — surfaces
Flutter does not reach (iOS widgets, Android overlays) must be written
natively, which is why the ambient layer is scheduled as separate work.

**Architecture.** I fixed layer boundaries before features. `lib/domain/` is
pure Dart with no Flutter imports and owns the invariants — the one-to-seven
rule, local-day rollover, positive-history aggregation, unlock thresholds;
`lib/data/` owns storage, notification scheduling and export; `lib/sprite/`
owns atlas parsing and rendering; `lib/application/` is a
presentation-independent coordinator deliberately outside `lib/ui/`. A visual
reskin therefore cannot move persistence or behaviour — demonstrated when the
approved design was applied without touching domain logic — and
the invariants are unit-testable without a widget harness.

**Rendering.** A small `CustomPainter` driven by a `Ticker`, rather than the
Flame game engine: a game-engine dependency for one animated actor is
disproportionate and would relocate animation state out of the tested layer.

**Data.** Everything is local. State is a versioned JSON document written by
flush-then-rename; events are append-and-flush newline-delimited JSON. There is
no account, no server and no analytics service. The justification is partly
ethical — the community research records explicit refusal to hand
mental-health-adjacent data to small developers' cloud services — and partly
methodological, since it makes evaluation possible without data
infrastructure. §5 records the cost: retention cannot be measured the way any
cited study measures it.

**Process.** I develop against written task specifications, each stating goal,
file scope, constraints and acceptance criteria before implementation begins,
and I accept a change only after reading the full diff and running the build
and test suite locally; user-visible changes are additionally walked through on
a device or simulator before they land. Every feature must state which ADHD
problem it solves; if that mapping cannot be stated, the feature is not built.
This constitution is recorded in `docs/PRODUCT-PRINCIPLES.md` and several of
its rules are enforced by tests rather than by discipline (§5).

### 2.2 Research method

Four bodies of evidence were gathered, deliberately of different kinds so each
could check the others.

*Community accounts.* I read high-engagement threads and their top comments
across three ADHD subreddits over two sweeps — one on tool abandonment, one on
the condition's daily texture — recording per-thread links and vote counts so
every claim remains traceable.

*Store reviews.* I collected 4,754 reviews via the public Apple review feed
(1,154: Finch 400, Tiimo 350, Numo 254, Habitica 150) and a Play scraper
(3,600: Finch 1,612, Habitica 1,537, Numo 339, Tiimo 112), deliberately
oversampling one- to three-star reviews on the Play side. That choice is
recorded next to every figure it affects: Play proportions indicate the
*concentration* of a complaint, not its population prevalence.

*Literature.* I ran a structured search across sixteen questions covering the
mechanism, the safety rules, and claims I had been repeating, treating
contradicting evidence as the most valuable output and recording "no credible
evidence found" where that was the truth rather than substituting adjacent
work. The result is a 230-row citation table recording, per row, study design,
sample, population mismatch, whether the claim is supported, and retraction
flags checked against both OpenAlex and Crossref (two flagged, both disclosed).
I additionally verified eight design-critical DOIs directly against the
Crossref API — all eight resolved with matching titles — and checked the
Altgassen finding line by line against the published abstract.

*Limitations, stated up front.* All community strands sample self-selecting,
self-identifying, predominantly English-speaking online populations; store
reviews are written by people still using a product, Reddit largely by people
who left. Self-identification is itself a methodological problem: executive
function rating scales and performance tests dissociate (median *r* = .19,
[Toplak et al. 2013](https://doi.org/10.1111/jcpp.12001)), so case-control
effect sizes cannot be transferred to a self-identifying sample — only the
weaker claim that self-rated difficulty predicts real functional impairment
([Barkley & Murphy 2010](https://doi.org/10.1093/arclin/acq014)).

---

## 3. Implementation

**Core loop.** Tasks, sprite engine, unlocks, local notifications
and the JSONL event log, on both platforms.

**Design and accessibility.** The approved visual design plus a
semantics rework — custom tap targets own container semantics above their
gesture handlers, decorative art is excluded from the accessibility tree,
onboarding scrolls on short viewports.

**Raising system.** State schema v2 with in-place migration, growth
stages derived rather than persisted, a treat economy, a full-day pet schedule,
long-press interaction, and a collection gallery with no progress bars.

**To-do baseline.** Schema v3. Tasks become ID-addressed objects of
kind `daily` or `oneOff`, capped at one to seven; quick capture requires only a
title; one-off tasks never carry age or overdue data. Positive history derives
only from completion events and renders only weeks containing completions — no
streak, gap, zero or missed-day state exists anywhere in the product.

**Stability.** A quick-capture crash on dialog dismissal, and an Android
release build that black-screened because release resource shrinking
stripped the notification icon — the fix keeps notification failures from ever
blocking startup.

**Own-pet hatch loop.** The differentiating feature. The user
photographs their animal; the app assembles a request package; a sprite pack
(`.pettodopet`) produced by the image-generation pipeline is imported and
installed atomically into application documents, and a runtime registry merges
bundled pets with installed packs. A later change made onboarding list the live
registry instead of a hardcoded single pet, and cleaned up exported request
archives that previously accumulated indefinitely.

**Animation quality.** The idle animation
read as choppy, something I noticed in my own daily use of the shipped build —
I am inside the target population, which the evaluation treats as a stated
limitation rather than a secret. Measurement located the cause: the six idle
frames are generated independently, so 37–46% of pixels change between
neighbouring frames and the silhouette drifts about 4 px — six similar dogs
rather than one dog breathing. The fix holds a still frame while the pet rests,
on the reasoning that the sprite contract itself describes idle as a
"low-distraction" loop, and that a resting companion should be restful.

**In progress, not yet part of the application.** A reworking of the notification
layer — new copy in the pet's voice reporting its own day, randomised selection,
timing jitter, and back-off after unopened days. I am holding it unmerged
because the literature contradicts two of its three mechanisms (§6).

---

## 4. Results

### 4.1 The working application

All screenshots below are from one continuous session on an iPhone 17 Pro
running the current build, using a pet the user hatched from their
own photographs. They are ordered as a user would meet them.

**Figure 1 — Home with a mixed task list.**
![Home showing a completed daily task, two outstanding dailies and a one-off](../artifacts/screenshots/01-home-mixed-list.png)

The pet occupies the top half of the screen and the task list the bottom: the
proportion is the argument. The pet is not an ornament attached to a to-do
list, it is what the screen is about, and the tasks are what a user
encounters on the way to it. The list shows both task kinds — three recurring
items and *Call the vet*, marked "Just once" — and the distinction is carried
by that quiet subtitle alone. There is deliberately no due date, no age, no
overdue marker and no count of what remains; a one-off task captured weeks ago
looks exactly like one captured this morning. The task area is a bounded
scrolling region rather than an expanding list, so the maximum of seven items
can never grow into a full-screen wall. The header reads "Today's little
things", and the completed item stays visible in warm tint rather than
disappearing or being struck through.

**Figure 2 — Quick capture.**
![The Jot it down dialog with the text "Call the vet" entered](../artifacts/screenshots/02-quick-capture.png)

Capture is two steps: tap *Jot it down*, type, confirm. The field is
autofocused, only a title is required, and the placeholder — "A thought before
it slips away" — names the problem it solves. This is the ADHD symptom with the
shortest fuse: a thought that leaves working memory in seconds cannot survive a
form. Anything captured this way defaults to a one-off, because forcing a
recurrence decision at capture time is exactly the friction that loses the
thought. The dismissal option is worded "Not now" rather than "Cancel" or
"Discard".

**Figure 3 — Completing a task.**
![A completed task card in warm tint with a filled check, and the treat counter increased to 2](../artifacts/screenshots/03-completion-moment.png)

Completion produces warmth and nothing else: the card takes a warm tint, the
circle fills, the pet plays a brief happy animation, and a treat drops — the
counter has gone from one to two. There is no score, no streak, no progress
bar and no "3 of 4 done" summary anywhere on the screen, because a progress
indicator is also a deficit indicator. The treat is the only currency, it is
spent on feeding the pet, and spending it is optional.

**Figure 4 — The Little Theater, shown when the day's list is finished.**
![A full-screen celebration with the pet enlarged, particles, a +3 treat award, and the message "Choco Two nuzzles you happily — thank you for today"](../artifacts/screenshots/04-little-theater.png)

Finishing everything on the list triggers the one moment the application makes
a fuss about: the pet fills the screen, particles rise, three bonus treats are
awarded, and the message reads "Choco Two nuzzles you happily — thank you for
today". The dismiss button says "Thank you, Choco Two", which keeps the
exchange between the user and the animal rather than between the user and a
scoreboard. This is the emotional peak of the design and the moment the whole
reward loop exists to reach. It is also, by construction, the *only* moment
with this weight — there is no equivalent screen for failure, because no
failure state exists.

**Figure 5 — Positive history.**
![The "Things we did together" screen showing one week with one dated group of three completed tasks](../artifacts/screenshots/05-positive-history.png)

The history screen is the clearest single expression of the safety
architecture. It reads "This week, you and Choco Two did 3 things together",
and lists only Thursday, because Thursday is the only day with completions.
Days without completions are not rendered as empty, greyed, or zero — **they do
not exist in the data model at all**, so no view can accidentally surface them.
There is no streak counter, no calendar grid with gaps to read as failure, and
no comparison against a previous week. The framing is "things we did together",
not "your completion rate".

**Figure 6 — The collection.**
![The collection screen showing two pets, Choco and the selected Choco Two, above a grid of locked keepsakes reading "A little mystery"](../artifacts/screenshots/06-collection.png)

Two things share this screen. The pet shelf shows both the bundled pet and the
user's own hatched pet, with the active one outlined — the runtime registry
described in §3 made visible, and the point at which the differentiating
feature becomes tangible to the user. Below it, unlocked keepsakes would appear
as illustrated items; locked ones show a paw silhouette and the words "A little
mystery". They carry no progress bar, no unlock threshold and no "2 more to
go", so the gallery cannot be read as a list of things not yet earned.

**Figure 7 — Settings.**
![The settings screen showing the pet name field, the four tasks with their recurrence labels, the evening notification toggle and time chips](../artifacts/screenshots/07-settings.png)

Settings is deliberately short. Tasks are listed with their kind stated in
words ("Every day" against "Just once") and removed with a single control;
there is no archive, no completed-items list and nowhere for finished work to
accumulate. The notification section is one toggle and three fixed times, and
its subtitle is phrased as something the pet does rather than something the
user must configure. Notifications are off until explicitly enabled, and a
denied permission is never requested again.

### 4.2 The hatch loop, end to end

The acceptance walkthrough for the differentiating feature was performed on the
same device from a clean install: onboarding → hatchery → photograph → export
of a 139 KB request archive → import through the real iOS document picker →
both pets listed with the new one selected → switching between them →
completing onboarding → Home showing the imported pet with its hatch ceremony —
ending with zero leftover archives in documents. Two further screenshots in the
repository record the ceremony and the resulting Home screen
(`artifacts/task-008/screenshots/`).

### 4.3 Implementation findings

Three findings from building it are results in their own right. A custom file
extension is unpickable in the iOS document picker unless the app declares it:
the picker produces a dynamic UTI and Files greys the file out, fixed by
declaring `UTExportedTypeDeclarations`. Re-importing a pack for the currently
selected pet paints a disposed image during the asynchronous gap unless the
replacement atlas is loaded before the old one is disposed. And exported
request archives accumulated indefinitely because cancellation deleted the
request folder but not the archive beside it — found by inspecting the
simulator's container, where the previous day's 139 KB archive was still
sitting.

### 4.4 A negative result: the pixel-art experiment

The fourth result is negative and reported as such. To test whether a pixel-art
style would improve inter-frame consistency, I first generated a pixel version
through the sprite pipeline's own pixel preset: the output was not pixel art —
13,713 unique colours against fewer than 32 for the genuine article. Mechanical
post-processing (downsampling plus palette quantisation) did produce true
23-colour pixel art but destroyed recognisability, because the eyes and muzzle
are defined by exactly the detail downsampling removes first. What worked was
constraining generation directly — a 64×64 logical grid, blocks aligned to it,
a 24-colour palette, no anti-aliasing — which produced genuine pixel art that
kept the identity anchors (the silver-brown muzzle, the brow spots, the floppy
ear silhouette). A six-frame idle strip built from that reference measured 14%
inter-frame drift after quantisation, against 42% for the current style, with
frame area stable to within 0.2 percentage points: the silhouette stops
breathing in and out between frames. The improvement is real but partial — 14%
is still far above what a hand-animated loop would show — and the aesthetic
choice it enables also answers the "infantile" objection documented against the
category leader in §1.3.2.

---

## 5. Testing and evaluation

### 5.1 Software testing

`flutter test` passes 47 tests across 16 files — a figure I verified by
running the suite, not by quoting it; the notification rework adds five more, including a lint that fails the build if
invitation copy ever regains a forbidden phrasing. Coverage concentrates on the
invariants the product promises its users: schema v1→v2→v3 migration; day
rollover, including that rolling over multiple missed days leaves no historical
markers; one-off isolation from daily rollover; treat and unlock edges; the
sorted, capped notification window with one fire per task per day and no
re-asking after permission denial; local-week positive-history aggregation;
JSONL round-trips; sprite atlas frame mathematics; pack install and validation;
and accessibility semantics boundaries. The intent is that the red lines are
enforced by tests rather than by discipline.

Gaps before submission: no end-to-end automated UI test; the ambient layer will
need platform-specific test provision; and Android notification timing needs
device-level verification, since the review corpus shows scheduled
notifications failing or arriving in batches under OEM battery policies to be a
category-wide defect (111 of 1,537 Habitica Play reviews, 63 of them one or two
stars).

### 5.2 User evaluation

The full plan is in `thesis/02-user-testing-plan.md`: five to ten seed
participants who are ADHD-leaning pet owners, recruited through my personal
network only; a fourteen-day run; a short questionnaire at days 7 and 14;
user-initiated local data export as the only data channel; and qualitative
red-light monitoring for guilt or uncanny reactions to the user's own animal,
treated as a finding that outweighs any retention number. Covert recruitment in
ADHD communities is excluded both ethically and pragmatically — the community
research documents moderators publicly naming products for stealth marketing.
Ethics approval is the longest-lead-time item and the first question for the
school.

Two revisions to the evaluation follow from the literature and are recorded
here because they change what the evaluation can claim. First, the community
benchmark of ">50% retention at two weeks" turns out to conflate two
incompatible frames: real-world median 15-day retention for mental-health apps
is 3.9% ([Baumel et al. 2019](https://doi.org/10.2196/14567)), while recruited
trials run near 75% and report usage a median 4.06× higher than real-world use
of the same programs ([Baumel et al. 2019](https://doi.org/10.1093/tbm/ibz147)).
A recruited seed group is a trial population, so >50% is a weak bar in that
frame and an extraordinary one in the other; the report will state which frame
it is in. Second, two weeks is the wrong window anyway: the review corpus
locates two failure points, days 2–4 when setup enthusiasm fades and roughly
the second month when novelty does. A day-60 check is added. Unblinded
self-report is additionally the most inflation-prone outcome in this field —
behavioural-intervention effects in children collapsed to non-significance
under probably-blinded assessment
([Sonuga-Barke et al. 2013](https://doi.org/10.1176/appi.ajp.2012.12070991)) —
which the analysis acknowledges by privileging the logged event data over
questionnaire answers wherever the two disagree.

---

## 6. Conclusion and future work

At mid-term the application does what it was specified to do, and the research
conducted for this report says the specification was partly wrong. That is the
honest summary, and the remaining work follows from it rather than from the
original plan.

**Resolve the notification design against the evidence.** The unmerged branch
implements randomised copy, timing jitter, and exponential back-off after
unopened days. The literature supports none of the three as mechanisms: the
closest test found a purpose-built 30-message bank no better than a single
fixed string ([Bell et al. 2023](https://doi.org/10.2196/38342)); jitter is
opposed by cue-consistency accounts of habit formation
([Lally et al. 2010](https://doi.org/10.1002/ejsp.674)); and one trial found
*less* frequent notification produced less viewing and actioning
([Morrison et al. 2017](https://doi.org/10.1371/journal.pone.0169162)). Worse,
withdrawing contact is ambiguous by construction, and rejection sensitivity is
defined as readily perceiving intentional rejection in ambiguous behaviour
([Downey & Feldman 1996](https://doi.org/10.1037/0022-3514.70.6.1327)) — so
back-off may be a guilt pathway rather than a protection. The copy rewrite is
retained on separate grounds; the two mechanisms are under review.

**Move from time-based to event-based cues.** The clearest evidence-led change
available and not yet built: anchoring a task to "after dinner" rather than to
19:00 uses the prospective-memory channel that is spared in ADHD adults rather
than the one that is impaired, and matches the cue type the forwarded expert
feedback independently proposed.

**Design the return screen and an explicit pause.** Zero punishment does not
prevent an accumulated backlog from speaking — the *shame reminder*. Two
mechanisms answer it: a first screen after absence that shows the pet's own
accumulated news rather than the user's arrears, and a deliberate pause action
that reframes absence as chosen rather than failed.

**Promote export to a user-facing backup.** The application is local-only, the
pet is generated from the user's own animal and is therefore irreplaceable, and
data loss is the top-voted complaint against the category leader — which at
least has accounts to restore from. The export mechanism exists; making it a
visible backup with an honest explanation is a small change against a
disproportionate risk.

**Finish the style decision, then build the ambient layer.** Pixel art is
technically viable (§4), and the ambient layer has the strongest single piece
of user evidence in the review corpus — a five-star review describing the
widget's pet speaking on a day the user had already given up. It is sequenced
after the style decision because the asset form determines what the widget
draws, and it will not be built before the Android battery-policy and
notification-batching risks are addressed.

**Evaluation.** Ethics enquiry, recruitment, the fourteen-day run with a day-60
follow-up, and analysis. The outstanding intellectual work is deciding what the
project claims when its central mechanism is, on present evidence, unproven —
and running an evaluation honest enough to find out.

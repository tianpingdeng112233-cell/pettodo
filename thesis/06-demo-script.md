# 演示视频成片稿（分镜重排 + 英文旁白逐字稿）

> 2026-09-01 定稿。时长框架为导师要求：**开头介绍 1–1.5 分钟，产品功能 5–5.5 分钟，
> 技术与代码结构 1 分钟**，全片 ≈ 7:15–8:00。
> 录制调度、造号清单、红线自查沿用 [05-demo-shotlist.md](./05-demo-shotlist.md)；
> 本文件的分段时长与旁白为成片正典，与 05 冲突处以本文件为准。
> 旁白配速按 **140 wpm** 写就，各段词数已对齐时长，照念即可。

## 时长总表

| 段 | 内容 | 目标时长 |
|---|---|---|
| Part 1 | 开头介绍（动机 + 设计论点） | 1:00–1:30 |
| Part 2 | 产品功能（8 个 clip） | ≈5:15 |
| Part 3 | 技术与代码结构 | ≈1:00 |

---

## Part 1 · 开头介绍（60–90s，≈190 词）

**画面**：标题卡（Pawside · MSc project COMP66060）→ Clip 1 冷启动全景慢镜
（宠物在房间 idle、bond 徽章、Today's little things 一屏收齐）→ 可插 1–2 张
报告插图（如「工具本身变成任务」示意）。Clip 1 在此消化，功能段不再单列。

> For adults with ADHD, the hardest part of a task is rarely doing it — it's
> starting it. Conventional to-do apps answer this with more structure:
> projects, priorities, streaks. But for this population, the tool itself
> becomes one more task to maintain, and every red badge is one more reason
> not to open the app. My user research pointed somewhere different: what
> actually initiates action is an external, concrete anchor — a dependant,
> another person, an animal that needs you. Pawside is my attempt to digitise
> that mechanism. It pairs a deliberately minimal to-do list — one to seven
> items, no projects, no calendar — with a virtual pet companion, and it
> enforces one rule everywhere: zero punishment. There are no streaks, no
> overdue states, and the pet never reacts negatively. Missing everything
> produces silence, not guilt. Everything runs offline on the device — no
> account, no server. Over the next five minutes I'll walk through the app the
> way a user experiences it: onboarding, the task list, reminders, focus
> sessions, feeding, the pet's room, and the floating companion. I'll close
> with a minute on the architecture.

---

## Part 2 · 产品功能（≈5:15）

各 clip 画面沿用 05 分镜，此处只标压缩后的时长与差异；旁白为逐字稿。

### Clip 2 · Onboarding（50s，fresh 态，≈105 词）

画面同 05（S1 领养所九宫格 → S2 命名骰子 → S3 emoji chips → S4 中场庆祝 →
S5 悬浮授权 → Home 首胜），操作节奏加快，命名/选 chips 不犹豫。

> Onboarding is built to establish the relationship before asking for any
> productivity. You choose a pet from the adoption shelter, name it — there's
> a dice button if naming feels like work — then pick three "little things"
> from emoji chips, so the first list fills itself in seconds. Halfway
> through, the app celebrates: the important part is already done. The final
> step invites the pet to stay on your home screen — that's the Android
> overlay permission, framed as an invitation, and entirely optional. You land
> on the home screen with your pet already living there. Total friction: under
> a minute, no account, no tutorial.

### Clip 3 · Todo 及格线 + 正向历史（45s，≈100 词）

> The task list is capped at seven visible items — an upper bound from user
> research, below the point where a list turns avoidant. Checking one off
> drops a snack, and the pet reacts. Adding a one-off takes one line; notes
> are there if you want them. And this is the history screen: it only tells
> you how many things you and your pet finished this week. There is no streak,
> no red, no count of what you didn't do. That's the zero-punishment red line,
> and it's enforced everywhere in the app — not just here.

### Clip 4 · 到时提醒（40s + 通知补拍镜头，≈90 词）

开拍即设 3 分钟后提醒，转录 Clip 5，到点回来补通知特写（同 05 调度）。

> One-off tasks can carry a timed reminder — a concrete date and time,
> distinct from the daily rhythm reminders. Once set, the task moves into a
> "Coming up" section with its time tag. The notification, when it fires, is
> written in the pet's voice — an invitation, not an alert — and it fires
> exactly once. If the moment passes, the tag simply comes off and the task
> returns to the list. No overdue state, no trace. This is prospective memory,
> externalised, without the guilt debt reminders usually accumulate.

### Clip 5 · 专注 focus（45s，≈95 词）

> Focus sessions digitise body doubling — working alongside someone. You pick
> a length, five to forty-five minutes, optionally bind one of today's tasks,
> and your pet curls up and sleeps beside the timer. Time becomes visible,
> concrete, and shared. Finishing drops a snack and a warm acknowledgement,
> plus an optional one-tap "mark it done". And crucially — ending early gets
> the same warmth. There is no "session failed", no withered plant. The
> session simply ends, and the pet is glad you stayed as long as you did.

### Clip 6 · 投喂与羁绊（45s，≈95 词）

> The second growth axis is bond. You spend snacks on food — seven items in
> three tiers — and feeding grants bond experience equal to the price. Here
> the bar fills and the bond levels up: a new title, a new badge, a small
> celebration. What's deliberately absent matters more: there is no hunger
> meter. The pet is never hungry, never neglected, and being away costs
> nothing. Feeding is a gift, not an obligation — the mechanic rewards
> presence without ever punishing absence.

### Clip 7 · 房间与家具（45s，≈90 词）

> The pet lives in a room. Furniture arrives two ways: milestone pieces unlock
> free at cumulative completion counts — here, the thirtieth completion
> unlocks the pet bed — and shop pieces are bought with snacks. Each piece
> goes into a fixed slot: buy it, and it's placed — no fiddly dragging. The
> room also feeds back into the system: a cozier room gives a small, capped
> bonus to bond gains, so decorating the pet's home is itself an act of care.

### Clip 8 · 悬浮宠（35s，Android 桌面，≈75 词）

> Outside the app, the pet can live on the Android home screen as a floating
> companion. It idles quietly, and occasionally offers a small speech-bubble
> invitation — pure invitation copy, which disappears on its own after a few
> seconds. Tapping it brings you back into the app. The anchor stays present
> in your environment, the way a real animal does, without ever demanding
> anything from you.

### Clip 9 · 功能段收束（10s，≈25 词）

主屏全景定格（同 05 Clip 9 画面），旁白直接切入 Part 3。

> Task anchoring, time externalisation, and warmth-only feedback — three
> intervention axes, one companion. That's Pawside. Now, one minute on how
> it's built.

---

## Part 3 · 技术与代码结构（60s，≈135 词）

**画面**：分层架构图（domain/data/sprite/application/ui，可用报告插图）→
IDE 里 `lib/` 目录树一扫 → rig pipeline 产物（正典姿势图 + 部件框叠加）→
终端 `flutter test` 跑绿收尾。

> Under the hood, Pawside is a Flutter app with a strictly layered
> architecture. The domain layer is pure Dart — it owns the task invariants,
> day rollover, and unlock thresholds, with no Flutter imports, which makes it
> exhaustively unit-testable. The data layer handles persistence: an atomic,
> versioned JSON state file plus an append-only event log — fully local, no
> account, no server. The sprite layer renders pets with a custom painter at
> eight frames per second — no game engine. Pets ship in two coexisting
> formats: legacy frame atlases, and rig pack v3, where canonical pose images
> plus AI-detected part boxes drive a per-species template skeleton, produced
> by a Python pipeline. An application coordinator keeps the UI a pure skin —
> and two hundred automated tests, including golden-image baselines, guard all
> of it.

---

## 配音自查

- 全片旁白 ≈1,000 词 ≈ 7:10 @140 wpm；某段念快了别赶，宁可画面多停半秒。
- 词汇跟 CONTEXT.md 正典：adopt（不说 buy/unlock）、snacks/treats、bond、
  focus session（不说 pomodoro）、Coming up。
- 红线自查沿用 05：全片不得出现 streak/overdue/惩罚反应/催促文案。

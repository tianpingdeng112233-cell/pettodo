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
| Part 2 | 产品功能（9 个 clip，含孵化） | ≈5:30 |
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

## Part 2 · 产品功能（≈5:30）

每个 clip 自包含：「画面与操作」= 录制时在手机上做什么（秒标是节奏参考，
画面先录、旁白后配，不必掐死）；引文块 = 旁白逐字稿。
录制调度（fresh/熟号两态只切一次）与造号清单仍看 05。

### Clip 2 · Onboarding（40s，fresh 态，≈90 词）

**画面与操作**（节奏加快，命名/选 chips 不犹豫）：
1. 0–8s：领养所 3×3 九宫格，滑一眼后点选一只宠
2. 8–14s：命名页，**点骰子按钮随机换名 1 次**再确认
3. 14–22s：emoji chips 里点选三条 little things
4. 22–27s：中场庆祝动画完整放完
5. 27–35s：常驻邀请页 → 点同意 → Android 悬浮授权系统页允许
6. 35–40s：落到 Home，宠物已在房间，首胜提示收尾

> Onboarding is built to establish the relationship before asking for any
> productivity. You choose a pet from the adoption shelter, name it — there's
> a dice button if naming feels like work — then pick three "little things"
> from emoji chips, so the first list fills itself in seconds. Halfway
> through, the app celebrates: the important part is already done. The final
> step invites the pet to stay on your home screen — entirely optional. You
> land with your pet already living there. Under a minute, no account, no
> tutorial.

### Clip 2.5 · 孵化自家宠物（40s，≈75 词）

**画面与操作**（前置：Mac 上 `cd backend && GEMINI_API_KEY=… npm start` 起本地
后端，手机与 Mac 同一 Wi-Fi，用拍摄包 v2——孵化地址已指向 192.168.88.13:3000。
⚠️ 每台设备孵化配额 3 次，排练别真提交；配额用完可清后端 `data/state.json`）：
1. 0–8s：Settings → **Adopt your own pet**，入口特写
2. 8–16s：相册选 1–3 张真狗/猫照片（用你泰迪的照片），提交
3. 16–24s：孵化等待画面停一拍（真实生成几分钟，剪辑跳时）
4. 24–34s：**孵出时刻**：自家宠以像素形态现身，切换为当前宠
5. 34–40s：回主屏，自家宠已在房间里 idle

> And the pet doesn't have to be one of ours. Pick one to three photos of
> your real animal, and Pawside hatches them: the photos go in, and after a
> little wait, out comes your own pet, redrawn as a living pixel companion.
> This is the heart of the design — the anchor isn't a mascot. It's your
> animal, the one you already care for, now sitting beside your task list.

### Clip 3 · Todo 及格线 + 正向历史（45s，≈100 词）

**画面与操作**：
1. 0–8s：主屏列表全貌停一拍（3 条常规 + 1 条 one-off，造号态）
2. 8–16s：勾掉一条 daily——**等 Snacks 掉落动画和宠物开心反应放完**再动
3. 16–24s：点添加，一行输入快速记一件 one-off
4. 24–30s：进任务详情给它加一行 note，返回
5. 30–45s：打开正向历史，停在「这周你和 {pet} 完成了 N 件」让旁白说完

> The task list is capped at seven visible items — an upper bound from user
> research, below the point where a list turns avoidant. Checking one off
> drops a snack, and the pet reacts. Adding a one-off takes one line; notes
> are there if you want them. And this is the history screen: it only tells
> you how many things you and your pet finished this week. There is no streak,
> no red, no count of what you didn't do. That's the zero-punishment red line,
> and it's enforced everywhere in the app — not just here.

### Clip 4 · 到时提醒（40s + 通知补拍镜头，≈90 词）

**画面与操作**（开拍即设提醒，随即转录 Clip 5，到点回来补拍）：
1. 0–10s：编辑那条 one-off，提醒区切到「日期+时间」形态——镜头先扫一眼
   daily 的每日形态做对比
2. 10–18s：设成 **3 分钟后**，保存
3. 18–28s：回主屏，「Coming up」区块出现、时间标签特写
4. 补拍 A（约 3 分钟后）：通知横幅一响就录——宠物口吻邀请文案特写 →
   点通知进 app
5. 补拍 B（时间过后）：回主屏拍标签自动摘掉、任务回普通列表、无过期痕迹

> One-off tasks can carry a timed reminder — a concrete date and time,
> distinct from the daily rhythm reminders. Once set, the task moves into a
> "Coming up" section with its time tag. The notification, when it fires, is
> written in the pet's voice — an invitation, not an alert — and it fires
> exactly once. If the moment passes, the tag simply comes off and the task
> returns to the list. No overdue state, no trace. This is prospective memory,
> externalised, without the guilt debt reminders usually accumulate.

### Clip 5 · 专注 focus（40s，≈95 词）

**画面与操作**：
1. 0–8s：主屏点专注入口
2. 8–16s：滑条来回拖一下演示 5–45 分钟步长，停在 **15 分钟**
3. 16–22s：绑定一条今日任务，开始
4. 22–30s：计时屏停留——宠物蜷睡陪伴，时间在走
5. 30–40s：（剪辑跳时）完成结算：+1 Snack、温暖反馈、点一下
   「顺手标为完成？」可选按钮
6. 40–45s：补拍段：另起一次专注 → 中途提前结束 → 温暖回应特写（无惩罚）

> Focus sessions digitise body doubling — working alongside someone. You pick
> a length, five to forty-five minutes, optionally bind one of today's tasks,
> and your pet curls up and sleeps beside the timer. Time becomes visible,
> concrete, and shared. Finishing drops a snack and a warm acknowledgement,
> plus an optional one-tap "mark it done". And crucially — ending early gets
> the same warmth. There is no "session failed", no withered plant. The
> session simply ends, and the pet is glad you stayed as long as you did.

### Clip 6 · 投喂与羁绊（40s，≈88 词）

**画面与操作**（造号已把 bond XP 压到差一次投喂就升级）：
1. 0–10s：打开 Snacks 商店食物区，慢扫 7 件三档价目
2. 10–18s：买鸡肉丁（余额扣减入镜）
3. 18–28s：投喂——宠物进食动画放完，XP 条上涨特写
4. 28–40s：**升级庆祝触发**：新称号+徽章特写停一拍
5. 40–45s：回到主屏，名字旁新徽章+XP 条收尾

> The second growth axis is bond. You spend snacks on food, and feeding
> grants bond experience equal to the price. Here
> the bar fills and the bond levels up: a new title, a new badge, a small
> celebration. What's deliberately absent matters more: there is no hunger
> meter. The pet is never hungry, never neglected, and being away costs
> nothing. Feeding is a gift, not an obligation — the mechanic rewards
> presence without ever punishing absence.

### Clip 7 · 房间与家具（40s，≈90 词）

**画面与操作**（造号累计 28 次完成，差 2 次到 30；留空槽位）：
1. 0–10s：连勾 2 条任务，累计到 30
2. 10–20s：**宠物床解锁时刻**完整入镜 → 摆进地面槽位
3. 20–32s：逛商店家具区，用 Snacks 买星星串灯
4. 32–40s：摆上墙/角落槽
5. 40–45s：拉远房间全景收一眼（呼应温馨度加成）

> The pet lives in a room. Furniture arrives two ways: milestone pieces unlock
> free at cumulative completion counts — here, the thirtieth completion
> unlocks the pet bed — and shop pieces are bought with snacks. Each piece
> goes into a fixed slot: buy it, and it's placed — no fiddly dragging. The
> room also feeds back into the system: a cozier room gives a small, capped
> bonus to bond gains, so decorating the pet's home is itself an act of care.

### Clip 8 · 悬浮宠（35s，Android 桌面，≈75 词）

**画面与操作**（录前先在 app 内刷新一次，让邀请时点落在近处）：
1. 0–8s：从 app 退到桌面，悬浮宠出现（app 前台不显示，别在前台干等）
2. 8–22s：等/掐点邀请气泡冒出——纯邀请文案特写，让它自然存在几秒
   （8s 自动消失，别等满）
3. 22–30s：点击气泡回到 app
4. 30–35s：主屏承接一拍

> Outside the app, the pet can live on the Android home screen as a floating
> companion. It idles quietly, and occasionally offers a small speech-bubble
> invitation — pure invitation copy, which disappears on its own after a few
> seconds. Tapping it brings you back into the app. The anchor stays present
> in your environment, the way a real animal does, without ever demanding
> anything from you.

### Clip 9 · 功能段收束（10s，≈25 词）

**画面与操作**：回到主屏全景，宠物 idle（呼吸/眨眼），镜头静止定格 10s，
旁白念完直接切入 Part 3 画面。

> Task anchoring, time externalisation, and warmth-only feedback — three
> intervention axes, one companion. That's Pawside. Now, one minute on how
> it's built.

---

## Part 3 · 技术与代码结构（60s，≈135 词）

**画面**：分层架构图（domain/data/sprite/application/ui，可用报告插图）→
IDE 里 `lib/` 目录树一扫 → 孵化后端一瞥（终端里 backend 运行日志或
`rig_pipeline` 产物：正典姿势图 + 部件框叠加）→ 终端 `flutter test`
**202/202 全绿**收尾。

> Under the hood, Pawside is a Flutter app with a strictly layered
> architecture. The domain layer is pure Dart — it owns the task invariants,
> day rollover, and unlock thresholds, with no Flutter imports, which makes it
> exhaustively unit-testable. The data layer handles persistence: an atomic,
> versioned JSON state file plus an append-only event log — everything you do
> stays on the device, with no account. The one online step is hatching: a
> small Node service turns your photos into canonical poses, detects the part
> boxes, and returns a self-contained rig pack — after that, your pet lives
> entirely offline. Pets render through a custom painter at eight frames per
> second — no game engine — in two coexisting formats: legacy frame atlases,
> and rig pack v3, where pose images plus part boxes drive a per-species
> template skeleton. Two hundred automated tests, including golden-image
> baselines, guard all of it.

---

## 配音自查

- 全片旁白 ≈1,050 词 ≈ 7:30 @140 wpm；某段念快了别赶，宁可画面多停半秒。
- 词汇跟 CONTEXT.md 正典：adopt（不说 buy/unlock）、snacks/treats、bond、
  focus session（不说 pomodoro）、Coming up。
- 红线自查沿用 05：全片不得出现 streak/overdue/惩罚反应/催促文案。

# SPEC 016 — Onboarding v2「先建立关系,再谈功能」(⚖️2026-08-25 David 拍板)

设计正典:Claude Design 画布 artifact `4b9b7b74-ae02-4830-a79b-6bd5a4ce8730`
(工作文件 `docs/design/onboarding/`,六块板 + 五条批注)。竞对依据:
`thesis/04-competitor-borrowables.md`(Onboarding 节 #1-#10)。
拍板记录:Q1A 九宫格领养所 / Q2A 付费露出不推销 / 步骤按竞对精华重排。

## 流程

S1 领养所 → S2 相识命名 → S3 三件小事 → S4 中场庆祝 → S5 常驻邀请
(Android only)→ Home 首胜。iOS 走 S1–S4 落地。进度点只数 S1–S4。

### S1 · 领养所 "Who's coming home?"
- 3×3 网格渲染 **pet registry 里的全部预置宠物**(布局自适应数量:当前
  bundled 只有 Choco 时网格照常渲染已有项,9 只随 015 E 落地自动填满;
  不硬编码九个格子)。点选=选中态(primary 描边)+ 名字高亮。
- 底部一行「Your real pet can live here too — from your photos, unlockable
  anytime」+ chevron:V1 点击进入现有 hatch/adoption 说明页,**无付费流**。
- CTA "That's the one"。

### S2 · 相识命名
- 宠物大图 + 气泡:"Thanks for choosing me! What will you call me?"
- 输入框预填宠物预置名;**骰子按钮**从预置名池随机换(零成本逃生门);
  caption 沿用正典 "Any name makes me happy" + "you can change it later"。
- CTA "Nice to meet you, {name}"(实时带名字)。

### S3 · 三件小事(零打字)
- 宠物小图 + 气泡 "Which little things will we do together?";副标
  "Keep them tiny — pick up to three, change them anytime"。
- 预置 emoji chips(地板级):Get out of bed / Drink some water / Brush my
  teeth / Take my meds / Three deep breaths / Step outside for a minute;
  「My own thing…」dashed chip 打开键盘(唯一打字点)。
- 选择上限 3;0 选中时 CTA 文案即指令 "Pick at least one"(禁用态),
  ≥1 变 "These three!"(沿用正典,数量不足三也用该文案)。
- chip 数据映射现有 v3 任务模型(daily 默认;emoji 只是标签前缀)。

### S4 · 中场庆祝
- 全屏:跳跃动画帧 + 像素 confetti + "Our little routine is ready!"
- **首个奖励先于任何真实任务**:+1 零食,文案 "+1 Little Bone — for
  getting us started"(接现有零食经济,treat 名随所选宠物的 treat 定义)。
- CTA "Let's go home"。

### S5 · 常驻邀请(仅 Android 且 overlay isSupported)
- 迷你桌面预览(深色 launcher 示意 + 宠物 1x)+ 气泡 "Can I stay on your
  screen while you go about your day?";副标 "No reminders from out there —
  just company. You can change your mind in Settings."
- "Let {name} stay" 走 002-A 权限流(拒绝=静默继续,不重问);
  "Maybe later" 直接继续。iOS / 不支持设备跳过本屏。

### Home 首胜(落地态,非独立步骤)
- 预埋一条白送任务 "Give {name} a pat"(副标 "A free one, to see how it
  feels",高亮描边+sparkle),完成即正常触发庆祝+掉零食;它是一次性任务,
  完成后按正向历史正常沉淀,不占用户的 1-7 上限(预埋后总数≤7 保护)。
- Evening hello **撤出 onboarding**:首个 19:00-22:00 打开 app 时由宠物
  in-context 气泡询问(接受=现有 evening hello 设置开启;拒绝=不再问,
  Settings 可开)。通知权限索取也随之后移到该时点。

## 测试 seam(先红后绿)

1. 既有全量测试 = 回归闸,断言零改动(onboarding 旧测试按新流程重写属
   本卡交付,不算违反)。
2. 流程单测:步序与进度点/选宠→命名预填与骰子/chips 上限 3 与 CTA 文案
   态/S5 gating(overlay unsupported 跳过)/首胜任务预埋(计数保护)/
   evening hello 不在 onboarding + 首晚询问触发窗口逻辑。
3. golden:S1–S5 五屏 393pt 基线。

## Out of Scope

- 性格选择与「让用户教宠物」(Finch#3/#4,v3 增强)。
- 付费解锁流/IAP(入口只到说明页);9 只预置正典素材与命名(015 E);
  rig pack v3 导入(015 D)。
- iOS widget 引导屏(002-B 时补 S5 对位)。
- 已有老用户不重走 onboarding,零迁移。

## ADHD mapping

选择即情感投入(P1 宠物是打开的理由);零打字+地板级目标=启动摩擦最小化;
中场庆祝=多巴胺分节;scripted first win=首次交互必有完成回路;零罪疚文案
全程(语气双侧雷区)。

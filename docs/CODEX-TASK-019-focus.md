# CODEX-TASK-019 — Focus session (pet-accompanied timer + treat drops)

首句:先读仓根 `CONTEXT.md`(产品词汇表)与 `./CLAUDE.md`(身份卡与红线),再读
`docs/SPEC-019-focus-session.md`(行为正典,本卡与其冲突时以 SPEC 为准)。

**ADHD 映射(宪法一行)**:任务启动困难——宠物 body doubling 把启动变成陪伴邀请;同时外化
时间流逝对抗时间盲。

**分级**:T2(新用户可见行为,跨 domain/application/ui)。分支 `feat/focus-019`,base=main,PR 不自合。
**不依赖** 018 两个 open PR 的代码(房间/商店),入口落在现有 home_screen 上。

## 目标

单段前台专注计时,宠物陪伴,完成按时长掉 treats。全部行为见 SPEC-019「行为正典」节,
要点:滑条 5–45 步长 5;`每满 15 分钟 = 1 treat`(5/10→0);切后台/锁屏自动暂停、回前台自动续跑;
提前结束零惩罚零痕迹;完成后邀请休息(纯文案,无倒计时);可选绑定一条任务,结算屏可选
「顺手标为完成」;完成段进正向历史,**不计入** `lifetimeCompletions`/家具里程碑;进行中会话
不落盘(杀进程=提前结束)。

## 文件范围

- 新增 `lib/domain/focus_economy.dart`、`lib/application/focus_session_controller.dart`、
  `lib/ui/focus_*.dart`(屏/结算,2–3 个文件);
- 修改 `lib/domain/event_log.dart`(+`focusComplete('focus_complete')`)、`lib/ui/home_screen.dart`
  (入口)、`lib/ui/history_screen.dart`(渲染 focus 行);
- 测试对应新增。不碰 sprite/rig 层、不碰 v2 资产、不加依赖。

## 设计参照(已拍板定稿,像素稿转写;组件用仓内 PxCard/PxButton/StairBorder 现成件)

**文案纯英文,app 内不得出现中文。** 大数字(滑条值、倒计时)用 body 字体 Baloo 2 w700
tabular(Pixelify 数字难读,⚖️2026-08-30),其余标题沿用 display 字体。

1. **Set duration 屏**:顶部返回箭头 + 标题 `Focus`(display24),右上现有 treat 计数 chip。
   宠物坐姿 + 地面阴影 + 台词 `“Want to focus for a bit? I’ll nap right beside you~”`。
   白色 PxCard:居中大字 `25`(44px Baloo 700)+ `minutes`;像素滑条(轨道 stair-sm,
   填充 primary,方形白 thumb 描边 accentText);刻度标签 5/15/25/35/45;下行小字
   `Finish to earn 1 treat`(随档位动态 0–3)。
   下方:`Focusing on something? (totally optional)` + 任务选择卡(选中任务名 + `Change`)。
   底部主按钮 `Start focusing`(54px primary)。
2. **Focusing 屏**:极简。倒计时 `18:42`(76px Baloo 700 tabular)+ `of 25 minutes`;
   绑定时 chip `Working on “<task>”`;中部蜷睡宠物 + 漂浮 z z 动画 + caption
   `If you leave, I’ll pause for you`;底部虚线描边按钮 `That’s enough for now`
   (escape-hatch 惯例,点击=提前结束,直接回主屏,无确认弹窗无挽留)。
3. **Complete 屏**:宠物睁眼开心;标题 `Focus complete!`(display26);
   `You and <pet> focused for 25 minutes`;badge chip `+1 treat`;台词
   `“Let’s rest a little — I’ll be here when you’re ready~”`。
   绑定任务时出 PxCard:`Mark “<task>” as done while you’re at it?` + 两键
   `Not now` / `Mark done`。底部主按钮 `Back to the room`。0 treat 完成(<15min)
   不显示 +N badge,只有温暖文案,无「差一点」类措辞。

## 约束

- 零惩罚红线:提前结束/0 掉落路径不得出现任何失败、损失、催促语义;
- v2 双轨零回归;陪伴宠物复用现有 sprite 渲染与姿势(缺 side 走既有降级),不新增素材管线;
- 守仓内 `analysis_options.yaml`(lint 唯一事实源,别自设阈值);
- testWidgets fake-async 区禁 await dart:io(仓红线);
- 不写 `CODEX-JOURNAL.md`。

## 测试 seam(先红后绿,只在这些边界上加测试)

1. `treatDropForFocus`:5/10→0,15/20→1,30→2,45→3;非法入参抛 ArgumentError(对齐 awardTreats 风格);
2. `FocusSessionController` 状态机:pause/resume 累计 elapsed 正确;abandoned 不结算不产事件;
   completed 恰好一次 awardTreats + 一条 `focus_complete` 事件(复用 event_log 编解码测试层);
3. 里程碑口径:focus 完成后 `lifetimeCompletions` 与解锁集不变;
4. 结算屏「Mark done」走既有任务完成流程(掉任务 treat、计里程碑),不点则任务不变;
5. 回归闸:现有 `flutter test` 全绿。

## 验收

`flutter analyze` 干净 + `flutter test` 全绿;Android emulator 亲验:完整专注/切后台/提前结束/
绑定任务四条路径,重启后 treats 与历史保持。完成后原子 verb-first commit(一逻辑一 commit),
**不 push 不开 PR**(由 Claude 收货后处理)。

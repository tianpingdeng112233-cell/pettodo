# CODEX-TASK-021 — Timed reminder (once-on-date for one-off tasks)

首句:先读仓根 `CONTEXT.md` 与 `./CLAUDE.md`,再读 `docs/SPEC-021-timed-reminder.md`
(行为正典,与本卡冲突时以 SPEC 为准)。

**ADHD 映射(宪法一行)**:时间盲+前瞻记忆失灵——未来某刻的事外化为到点一次的宠物邀请。

**分级**:T2。分支 `feat/timed-reminder-021`,base=main,PR 不自合。

## 目标

one-off 任务可设「具体日期+时间」的一次性到时提醒;daily 每日时刻制不动。全部行为见
SPEC-021「行为正典」,要点:到点恰好一响、响过即止、错过静默;存量 one-off 旧每日提醒
原样继续生效,编辑时才切新形态(序列化双轨,交付红线);主屏 Today's list 下方新增
Coming up 区块(成员=带未来到时提醒的 one-off,时间一过标签摘掉、回普通列表,永无
过期/年龄痕迹,空则整块不渲染);完成/删除/改时取消未响通知;treats 与里程碑零变化。

## 文件范围

- `lib/domain/app_state.dart`(提醒模型双形态 + fromJson 双轨)、新增分组纯函数
  (`lib/domain/` 下,含 now 参数);
- `lib/data/notification_service.dart`(一次性 datetime 调度,复用现有通道与权限纪律);
- `lib/application/app_controller.dart`(schedule/cancel 联动);
- `lib/ui/task_editor_sheet.dart`、`lib/ui/home_screen.dart`;测试对应新增。
- 不碰 sprite/focus/room,不加依赖。**动画冻结令仍生效:不新增任何动画。**

## 设计参照(⚖️2026-08-30 定稿,转写;组件用仓内 PxCard/PxToggle/StairBorder 现成件,文案纯英文)

1. **one-off 编辑器**:kind 段选 `Just once`(bolt 图标)时,提醒区换成**琥珀色高亮块**
   (primary 描边 2px、内底 #FFF3E0):日历图标 + 标题 `Remind me once` + PxToggle;
   caption `One invitation at that moment, never repeated.`;下方两枚并排白底描边 chip:
   `[日历图标] Sun, Aug 31` 与 `[时钟图标] 15:00`,各自点开 date/time picker
   (日期下限=今天)。
2. **daily 编辑器**:现有形态基本不动(时钟图标 + `One gentle reminder` + toggle),
   时间按钮改成白底描边 chip 样式:`[时钟图标] Every day at 9:00 AM [>]`,点开 time picker
   ——与 one-off 的琥珀块一眼是两种东西。
3. **主屏 Coming up 区块**:位于 Today's little things 之下,区头=小日历图标 + `Coming up`
   (caption 色);成员卡与普通任务卡同构(checkbox+标题),标题下加一枚 badgeFill 小 chip:
   `[时钟图标] Sun, Aug 31 · 15:00`(13px);时间一过 chip 消失、任务回普通 one-off 列表;
   区块空则不渲染。卡面永不出现过期/年龄标记。

## 约束

- 通知红线:每任务每天最多一响、纯邀请口吻、拒权限不再问、错过不补发;
- 交付红线:老档旧 one-off 每日提醒行为零变化、零数据丢失;
- 守仓内 `analysis_options.yaml`;testWidgets fake-async 区禁 await dart:io(文件 IO 进
  runAsync);不写 `CODEX-JOURNAL.md`。

## 测试 seam(先红后绿,只在这些边界加测试)

1. 序列化双轨:旧 `{hour,minute}` roundtrip 无损且行为等价(每日制);新含日期形态
   roundtrip 无损;混存列表读入正确;
2. 分组纯函数:future timed→Coming up(按时间升序);过期 timed/无提醒/daily→原位;
   now 跨界(前一刻在区内、后一刻回列表)正确;
3. 通知调度:设/改/删/完成 → schedule/cancel 恰好一次;一次性提醒无第二发;
   legacy 每日调度零回归;
4. 回归闸:现有 `flutter test` 全绿。

## 验收

`flutter analyze` 干净 + `flutter test` 全绿;Android emulator 亲验:建 one-off 设 2 分钟后
提醒→Coming up 现身带时间 chip→到点一响且仅一响→chip 摘掉回普通列表零痕迹;完成任务后
未响通知不响;老档(带旧 one-off 每日提醒)升级后照常每日响。完成后原子 verb-first commit
(一逻辑一 commit),**不 push 不开 PR**(Claude 收货后处理)。

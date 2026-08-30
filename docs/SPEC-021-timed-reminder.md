# SPEC 021 — 到时提醒（timed reminder：one-off 的日期+时间一次性邀请）

⚖️2026-08-30 拍板（grill 全轮）：one-off 任务补上「具体日期+时间」的一次性到时提醒；
daily 保持每日时刻制不动。进论文交付（ADHD 前瞻记忆 time-based prospective memory 干预）。

**ADHD 映射（宪法一行）**：时间盲+前瞻记忆失灵——「未来某刻要做的事」在脑内保不住，
外化成到点一次的宠物邀请；零催促零羞耻语义防回避。

## 背景

现状：任务两种（daily/one-off，`TaskKind`），每任务可设 `TaskReminder{hour,minute}`
每日时刻提醒（含 one-off——语义错位正是本 spec 要填的缺口）；通知纪律见
PRODUCT-PRINCIPLES：每任务每天最多一响、纯邀请口吻、拒权限不再问。

## 行为正典（⚖️已拍板）

- **形态**：one-off 可设「日期+时间」一次性提醒（今天起，未来日期）；到点恰好一响，
  响过即止——不补发、不重复、错过（关机/勿扰）静默。daily 的每日时刻制原样不动。
- **编辑器**：选 one-off 时提醒区整体换形态，与 daily 视觉明显两种东西
  （不同图标+文案：`Remind me once on Aug 31 at 15:00` vs `Every day at 9:00`）。
- **存量照护（交付红线）**：已存在的 one-off 旧「每日时刻」提醒**原样保留继续每日生效**，
  用户下次编辑该任务时编辑器只提供新形态；序列化新旧双轨识别，零数据丢失。
- **主屏分区**：「Today's little things」**下方**新增已安排区块（英文文案工程自决，如
  `Coming up`）：成员=带未来到时提醒的 one-off；卡面显示未来日期时间标签；时间一过
  标签自动摘掉、任务回到普通 one-off 列表，卡面与普通 one-off 无异——永不出现过期/
  年龄/错过痕迹（红线）。区块为空时整块不渲染。
- **联动**：任务完成/删除/改时间时取消未响的通知；通知点开走既有 notificationTap 行为；
  treats 经济与里程碑口径零变化。

## 交付单元（1 张卡）

**021-A · 到时提醒全闭环**
- domain：提醒模型扩展（每日时刻制 + 一次性日期时间双形态，fromJson 双轨识别）+
  「任务列表→主屏分组」纯函数（scheduled 成员判定含 now 参数）；
- data：通知调度接一次性 datetime（复用现有 notification service 通道与权限纪律）；
- UI：task_editor_sheet 按 kind 换提醒形态；home_screen 新增 Coming up 区块与未来时间
  标签（到期摘除）；
- 文案纯英文，宠物口吻，设计稿拍板后转写入卡。

## 测试 seam（先红后绿，只在这些边界加测试）

1. **序列化双轨**：旧 `{hour,minute}` 与新含日期形态 roundtrip 各自无损；旧数据读入后
   行为等价（每日制不变）——交付红线测试；
2. **分组纯函数**：future timed → scheduled 区；过期 timed / 无提醒 / daily → 各归原位；
   区块排序按时间升序；now 推进跨界正确；
3. **通知调度**：设/改/删/完成对应 schedule/cancel 恰好一次；一次性提醒不产生第二发；
   legacy 每日提醒调度路径零回归；
4. **回归闸**：现有 flutter test 全绿。

## 验收

Android 模拟器亲验：建 one-off 设 2 分钟后提醒→出现在 Coming up 带时间标签→到点收到
一次通知、不再有第二次→标签摘掉任务回普通列表、无任何过期痕迹；完成任务后未响通知
不再响；带旧 one-off 每日提醒的老档升级后提醒照常每日响、编辑时切新形态；
`flutter analyze` 干净 + `flutter test` 全绿。

## Out of Scope

重复/自定义循环提醒；daily 任务日期化；snooze/稍后提醒；过期标记与补发；通知深链到
单任务；系统日历集成；提醒相关 treats 掉落变化；iOS 端调度差异处理（毕设 Android 优先）。

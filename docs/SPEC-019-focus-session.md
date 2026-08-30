# SPEC 019 — 专注（focus session：宠物陪伴计时 + treats 掉落）

⚖️2026-08-30 拍板（grill 全轮）：番茄钟形态的单段专注，宠物在计时屏陪伴，完成按时长掉
treats；不做强制番茄循环、不做惩罚、不引入第二货币。定位毕设交付：进报告（body
doubling / 时间外化干预）+ 演示视频。

**ADHD 映射（宪法一行）**：任务启动困难——宠物 body doubling，「陪你开工」把启动从意志力
问题变成陪伴邀请；同时外化时间流逝对抗时间盲。

## 背景

现状：app 无任何计时/专注能力；treats 唯一进账是任务完成（单件 1、日全套 3，
`treat_economy.dart`），出账为喂食与 SPEC-018 商店。本 spec 为 treats 增加第二条进账，
口径与货币不变。

## 行为正典（⚖️已拍板）

- **时长**：滑条 5–45 分钟、步长 5。结算「每满 15 分钟 = 1 treat」（15→1，30→2，45→3；
  <15 分钟段合法但 0 掉落，作热身微专注）。上限 45 暂不放宽，想继续手动再开一段。
- **陪伴**：计时屏宠物在场，复用蜷睡/打盹正典姿势（缺 side 走既有降级），零新增素材。
- **暂停语义**：切走 app / 锁屏即自动暂停，回来自动续跑；暂停无时限、无任何提示音或
  催促。计时只在前台走（elapsed 按前台累计，不按墙钟差）。
- **提前结束**：零惩罚——温暖回应文案、无奖励、无失败痕迹（不进历史、不留记录）。
- **完成结算**：掉落 treats + 宠物温暖反馈；随后**主动引导**「陪 {pet} 歇一会儿再来」
  （纯邀请文案，不倒计时、不循环）。
- **绑定任务（可选不强制）**：开始前可从今日任务/one-off 中选一条作陪伴语境；结算屏
  出现可选按钮「顺手把它标为完成？」，点了才走既有完成流程（照常掉任务 treat、计入
  里程碑），不点无事发生。
- **入口**：主屏独立入口，与任务列表平级（具体摆位工程自决，不动导航结构）。
- **台账**：完成段进正向历史（「你和 {pet} 一起专注了 N 分钟」，event log 新增
  `focus_complete` 事件，data 带 minutes/treats/taskId?）；**不计入**家具里程碑的
  累计完成数（`lifetimeCompletions` 口径不变）。treats 无日上限。

## 交付单元（1 张卡）

**019-A · 专注全闭环**
- domain：`focus_economy.dart` 纯函数 `treatDropForFocus(int minutes)`（⌊minutes/15⌋，
  仅对完成段调用）；`PetEventType.focusComplete('focus_complete')`；state 无新增持久字段
  （treats 复用、进行中会话不落盘——杀进程即视为提前结束，零惩罚语义天然兼容）。
- application：`FocusSessionController`（idle→running→paused→completed/abandoned 状态机，
  前台 tick 驱动，lifecycle observer 切后台暂停/回前台续跑）。
- UI：主屏入口；计时屏（滑条选时长→大字倒计时+陪伴宠物+温和的「先到这里」退出）；
  结算屏（掉落反馈、歇一会儿邀请、可选任务完成按钮）;history_screen 渲染 focus 事件行。
- 文案全走既有 i18n 通道，宠物口吻,零催促零羞耻。

## 测试 seam（先红后绿）

1. **掉落纯函数**：`treatDropForFocus` 边界表——5/10→0，15/20→1，30→2，45→3；
   负数/0 抛参错（对齐 `awardTreats` 风格）；
2. **状态机**：running→pause→resume 累计 elapsed 正确；abandoned 不结算、不产生事件；
   completed 恰好一次 awardTreats + 一条 `focus_complete` 事件（复用 event_log 编解码测试层）；
3. **里程碑口径回归**：focus 完成后 `lifetimeCompletions` 不变、家具解锁集不变（交付红线：
   老用户升级后解锁进度零漂移）;
4. **任务顺手完成**：结算屏按钮走既有 taskComplete 流程（掉任务 treat、计里程碑），
   不点则任务状态不变——state reducer 单测；
5. **回归闸**：现有 flutter test 全绿（经济/解锁/历史零回归）。

## 验收

- Android 模拟器：滑条选 15 分钟开专注→切后台再回来计时暂停/续跑正确→完成掉 1 treat、
  历史出现专注行、家具里程碑数不变；提前结束无任何负面痕迹；绑定任务→结算屏顺手完成→
  任务 treat 照常掉；重启 app 后 treats 与历史保持；
- 老档升级后第一屏与解锁进度零变化（带历史档亲测）；
- 计时屏宠物打盹动画正常（v2 与 rig 宠各验一只），报告可截图。

## Out of Scope

强制番茄循环/休息倒计时;>45 分钟档;白噪音/音景;专注统计图表;禁用手机/勿扰模式集成;
专注日上限与防刷;进行中会话跨杀进程恢复;专注计入家具里程碑;第二货币;悬浮宠
(overlay)联动;多人/社交专注。

# SPEC 017 — 悬浮宠接自家宠物 + 邀请式气泡(Android only)

⚖️2026-08-28 拍板:悬浮宠帧源接活跃宠物(含孵化的自家宠物);悬浮宠增加**邀请式提醒气泡**;
孵化后端**本地起服务**形态接通(生产部署仍按 ADR 0002 冻结)。仅安卓端,iOS 不做。

## 背景

现状悬浮层的帧是构建期从内置 Choco v2 图集切出的静态 drawable
(`tool/slice_overlay_frames.dart` → `R.drawable.overlay_*`),运行时只能换名字不能换宠;
孵出的 rig pack v3 宠物只活在 app 内。提醒全走系统通知,悬浮层零任务状态(宪法)。

## 交付单元(1 张卡,017-A)

**1 · 帧源运行时化**
活跃宠物变更(孵化导入/图鉴切换)时,Dart 侧把该宠物的 overlay 帧**离线烘焙**成 PNG
写入 app 私有目录,method channel 通知 `OverlayPetService` 重载;native 侧从文件加载,
无烘焙产物时回退内置 Choco drawable(零回归)。
- v3 宠物:复用 `RigDriver`(确定性 `RigPoseFrame`)+ 现有合成逻辑离线渲染
  idle(呼吸/眨眼)与 jumping 两组帧;
- v2 宠物(Choco/Lynne):复用 slicer 的切帧逻辑运行时切;
- 画布维持 192×208、整数 2× 缩放、8 fps、禁滤波抗锯齿(与现状一致)。

**2 · 邀请式气泡**
Dart 在 refresh 时把未来邀请时点(时间+文案)交给 service;到点悬浮宠旁冒一句气泡,
约 8 秒自动消失,点击进 app。系统通知照旧不动(零回归)。
- **合宪红线**:文案仅邀请式(如 "Want to look at today's little things?"),
  禁催促/内疚/任务数量/过期字样;气泡消失后悬浮层回到零任务状态;每日总次数
  不超过现有通知窗口的邀请数。

**3 · 后端本地接通**
`defaultHatchApiBaseUrl` 目前是占位假域名。改为可配置:`--dart-define=HATCH_API_BASE_URL`
覆盖,默认 debug 构建指向 `http://10.0.2.2:3000`(模拟器→宿主 Mac),release 维持占位。
README 补一段「本地起后端 + 模拟器全链路孵化」步骤。

## 测试 seam(先红后绿)

1. **烘焙确定性**:同一 pack 同参数两次烘焙,全帧 SHA-256 一致(仿 `overlay_frame_slicer_test`);
2. **channel 契约**:overlay payload 构造器单测——帧文件路径列表 + 气泡时点表的形状与回退分支;
3. **气泡时点映射**:通知窗口 → 气泡 schedule 的纯函数单测(含每日上限、过去时点剔除);
4. **回归闸**:现有 flutter test 全绿(v2 双轨、通知、slicer 零回归)。

## 验收

- 模拟器全链路:Mac 起 backend → app 孵化自家宠物 → 开悬浮层,桌面显示**孵出的像素宠**
  (非 Choco),3x 截图无绿边;
- 造一条近期邀请,气泡到点出现、8 秒消失、点击进 app;
- 无自家宠物/烘焙失败时悬浮层仍显示内置 Choco(回退路径演示);
- 屏幕关闭时停 tick(现状行为保持)。

## Out of Scope

iOS/widget;后端部署;气泡内直接完成任务;v3 宠物的 look/头部跟随上悬浮层
(只要 idle+jumping);IAP 门改动。

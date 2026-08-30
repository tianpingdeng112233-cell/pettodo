# Pawside(pettodo)— 工程上下文身份卡

ADHD-safe 自家宠物陪伴养成 app(Flutter,Android 优先)。对外名 **Pawside**,仓名/包名 pettodo。
读完本文件你就知道这是什么项目、处于什么阶段、遵守什么规则。

## Session 启动必读

1. 读本文件
2. 读 [CONTEXT.md](./CONTEXT.md)(产品词汇表:正典+_Avoid_)
3. `git log --oneline -10` + `gh pr list` 了解最近进展与待合 PR
4. 台账现场核实,不凭记忆断言(分支/PR/部署态)

## 项目定位(⚖️2026-08-28,ADR 0002)

**Manchester MSc 毕业论文项目(COMP66060),商业化冻结**。订阅/真 IAP、后端生产部署全部
frozen(台账保留不排期);剩余工作对齐毕设交付:终稿 8k 词、演示视频、报告截图质量。
015-E 预置宠量产已单项解冻并完成。

## 架构一分钟

- 宠物两代格式双轨:v2 逐帧图集(遗留,永不失效)+ **rig pack v3**(正典姿势图 + AI 部件框 + 模板骨架程序驱动),注册表按 `formatVersion` 路由
- 正典姿势:正面睁眼/闭眼/蜷睡必备,**侧视可选**(⚖️2026-08-28;缺失时跑步走正面蹦跳降级)
- 预置 8 只全 rig 化(Choco 三图 + 7 只四图),生产管线在 `tools/rig_pipeline`(Python CLI,`--pose-note` 可钉细节)
- 孵化后端 `backend/`(Node,仅本地/模拟器用,不部署)
- 分层:`lib/domain`(纯 Dart)/`data`/`sprite`/`application`/`ui`,详见 [docs/IMPLEMENTATION-NOTES.md](./docs/IMPLEMENTATION-NOTES.md)

## 🚨 仓内红线

- **rig 层的一切像素处理必须 CPU**,禁止 `Picture.toImage`/GPU 混合模式参与层烘焙——Impeller 不执行 clear/dstIn 擦除且测试(软件 Skia)测不出来。详见 IMPLEMENTATION-NOTES「Rig layer baking」节
- flutter testWidgets 的 fake-async 区 await dart:io Future 会 10 分钟死锁——文件 IO 进 `runAsync` 或用同步 API
- 零惩罚红线:宠物永不出现 failed/惩罚类反应
- v2 双轨零回归:任何改动不得让存量 v2 宠物失效

## 验收与工作流

- UI 验收用 **Android emulator**(`flutter emulators --launch meetpr`),不开 iOS 模拟器;金样测试 `flutter test --update-goldens` 刷新后必须肉眼核对
- Codex 派卡走 `docs/CODEX-TASK-*.md`(自包含:目标/范围/约束/验收/测试 seam)
- spec 正典:`docs/SPEC-015`(rig 管线)/`016`(onboarding)/`017`(overlay)/`018`(房间家具);重大取舍在 `docs/adr/`

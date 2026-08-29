# CODEX-TASK-015F — rig pack v3 侧视降级为可选(⚖️David 2026-08-28 拍板 A)

先读仓根 `CONTEXT.md`(有则读)。

## 背景与目标

跨姿势 AI 生成的 identity/画风一致性不可靠,产品拍板:**side.png 从 rig pack v3 必选降为可选**。
side 只服务「跑步」动作;side 缺失时跑步降级为正面姿势的快速蹦跳位移(正面 bob + 水平位移,常量集中,
不新增素材)。首个受益者 Choco:`assets/pets/choco/` 已就位 front-open/front-closed/sleep 三张 +
只含 `front` 段的 rig.json(**资产勿动**,manifest 需去掉 choco 的 side 字段——由你改)。

## 文件范围

- `lib/sprite/rig_definition.dart`:`RigDefinition.side` 可空;rig.json 缺 `side` 键合法,有则按现契约全量校验。
- `lib/data/pet_pack_service.dart` `_validateRigPack`:`side.png` 与 rig side 段成对可选(有 side.png 无 side 段、或反之 → 拒绝);其余校验不变。
- `lib/sprite/rig_pet.dart`:side 缺失时不 compose side 层(`sideLayers` 可空或空集),`sideWidth/Height` 相应处理。
- `lib/sprite/rig_pet_sprite.dart` / `rig_driver.dart`:`RigPetAction.running` 在无 side 时用正面降级——复用现有 front 绘制,叠加水平位移 + 快速 bob(参数进 `RigDriverParameters`,幅度用现有常量风格);有 side 的宠行为零变化。
- SPEC-017 overlay 跑步链路同一降级(它复用 rig 渲染则应自动生效,若有独立假设修正之)。
- `assets/pets/manifest.json`:choco 条目删除 `side` 字段;`lib/sprite/sprite_atlas.dart` manifest 解析中 rig 条目的 `side` 可选(缺失 → RigAssetDescriptor.sideAsset 为空)。
- `pubspec.yaml`:去掉 `assets/pets/choco/side.png` 条目。

## 约束

- 其余 7 只预置与用户导入的带 side 包:行为零回归。
- v2 图集双轨不动;hatch 后端与生成管线不动(仍产 4 张,契约兼容)。
- 不新增依赖;不 commit/push,改动留工作区。

## 验收标准

1. `flutter test` 全量绿(现有测试零回归;金样如因 choco 新形象变化,`--update-goldens` 刷新并肉眼核过)。
2. 无 side 的 rig 包(bundled 与导入两路)可加载、可选中、正面动作全量可用,`running` 走降级不崩。
3. 带 side 的包 running 行为与现状逐帧一致(驱动确定性快照测试维持)。

## 测试 seam(先红后绿)

- **包校验边界**(复用 008 seam):无 side 的 v3 包接受;side.png 与 rig side 段不成对 → 拒绝。
- **manifest 解析**:无 side 的 rig 条目 → descriptor sideAsset 为空;有 side 照旧。
- **驱动状态机**:无 side 时 `running` 映射到降级参数的确定性快照;有 side 快照不变。
- **加载边界**(复用内存 AssetBundle harness):无 side descriptor 经 `RigPetLoader` 加载成功且 sideLayers 为空。

## Out of Scope

生成管线/后端改为单图产出(另卡);其余 8 只转三图;跑步动画美术升级。

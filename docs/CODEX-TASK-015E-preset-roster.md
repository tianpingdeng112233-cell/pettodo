# CODEX-TASK-015E — Bundle the 7 preset rig pets and wire the registry

先读仓根 `CONTEXT.md`(有则读)。

## 目标

把已定版的 7 只预置宠(rig pack v3)接进 app 的内置宠物名单:用户在领养/收藏界面能看到并选用它们,渲染走已有的 rig v3 渲染器。资产文件已经解包放好在 `assets/pets/<id>/`(rig.json + pack.json + 4 张 RGBA PNG),**不要改动这些资产内容**。

## 名单(display name / species / treat)

| id | display_name | species | treat |
|---|---|---|---|
| shiba | Shiba | dog | Little Bone 🦴 |
| golden | Goldie | dog | Little Bone 🦴 |
| corgi | Corgi | dog | Little Bone 🦴 |
| husky | Husky | dog | Little Bone 🦴 |
| tabby | Tangerine | cat | Little Fish 🐟 |
| blackcat | Ink | cat | Little Fish 🐟 |
| ragdoll | Mochi | cat | Little Fish 🐟 |

## 文件范围

- `pubspec.yaml`:把 7 个 `assets/pets/<id>/` 目录下的 5 个运行时文件(rig.json + 4 PNG;pack.json 仅存档,可不进 bundle)登记为 assets。
- `assets/pets/manifest.json`:为 7 只各加一条 rig 格式条目(自定 schema,建议 `"format": "rig"` + species + 各资产路径 + treat),choco 的 v1 条目保持原样。
- `lib/sprite/sprite_atlas.dart` `SpriteAtlasLoader.loadManifest`:解析 rig 条目,产出 `PetAssetDescriptor`(`format: PetAssetFormat.rigV3`、`source: PetAssetSource.bundled`、带 `RigAssetDescriptor`,资产字段填 bundle 路径)。v1 条目解析逻辑不动。
- 注册表/加载链路(`lib/application/app_controller.dart` 等):确认 bundled rig descriptor 会经由现有 format 路由走 `RigPetLoader`(`lib/sprite/rig_pet.dart` 的 `_readString`/`_readBytes` 已支持 bundle 路径);如路由处有「bundled 必是 v1」的隐含假设,修正之。
- 领养/选择界面若名单是从 manifest 派生的则应自动出现 7 只;若有硬编码名单,补上。

## 约束

- v2 双轨零回归:choco 及用户导入的 v1/v3 包行为不变。
- 不动 hatch 流程、后端、生成管线。
- 不新增依赖。
- 不 commit、不 push;改动留在工作区。

## 验收标准

1. `flutter test` 全量绿(现有测试零回归)。
2. manifest 解析出 8 条(choco v1 + 7 rig),每条字段正确。
3. bundled rig pet 能被加载(单测证明,不需要模拟器——模拟器验收由 Claude 做)。

## 测试 seam(先红后绿)

- **manifest 解析边界**(复用 008 已有 manifest/registry seam,`sprite_atlas` 相关测试处):喂含 rig 条目的假 manifest → 断言 descriptor 的 format/source/species/资产路径;畸形 rig 条目(缺字段)的行为有明确断言。
- **bundled rig 加载边界**:用假 AssetBundle 喂 rig.json + PNG bytes,断言 `RigPetLoader` 能按 bundle 路径加载 bundled descriptor(与 fileSystem 路径行为对齐)。

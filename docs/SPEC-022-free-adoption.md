# SPEC-022 — 全免费领养与去收费化（⚖️David 2026-08-30 拍板）

## 背景与拍板链

- ADR 0002 冻结商业化后，App 内仍保留 SPEC-015 的订阅占位门（$9.99/月文案 + 本地
  `hatch-feature-gate.json` 假解锁）。David 2026-08-30 拍板：**App 内彻底不出现收费**，
  报告随之改口径（本条覆盖 ADR 0002「保留不拆」的修订见该 ADR 文末）。
- 同日拍板：老用户没有领养预置宠的入口是缺口；补「adopt」入口，**全部免费**，
  不引入购宠经济（曾议的 treats 购宠因触 App-D2 红线被否，不复活）。
- 快速记录「Jot it down」60 字弹窗换成完整编辑面板（方案 B，2026-08-30 拍板）。

## 交付单元

### 022A 免费领养 + 拆收费门
1. Collection 宠物架末尾加一个「adopt」格：打开预置宠 roster（复用 onboarding 的
   领养 grid 数据源，绝不硬编码），列出尚未领养的预置宠；点选仅本地高亮，
   进入命名页（含骰子随机名）确认后才完成领养入架并切换为当前宠，
   中途返回不产生任何领养（2026-08-30 review 修订：防连点多只绕过命名）。
2. own-pet 孵化去收费：删除 `lib/data/feature_gate.dart` 及全部价格/订阅/试用文案
   （hatch_request_screen 的 Unlock 卡、settings 里的价格行）；孵化入口直接可用。
   3 次孵化尝试额度保留（成本约束，与钱无关）。
3. 存量照护（交付红线）：已写过 `hatch-feature-gate.json` 的设备升级后行为不变
   （文件被忽略，不迁移不报错）；`selectedPetId`、已孵化宠、宠物架不受影响；
   带历史的老用户升级后第一屏与升级前一致。旧档（无 adoptedPresetPetIds 字段）
   回填=全部 bundled 预置宠——升级前架上本就列出全部预置，只回填 selected 会让
   其余宠从架上消失（2026-08-30 review 修订）；installed 同 ID 覆盖包不算 preset。

### 022B 添加即编辑
- Home 的「+ Jot it down」不再弹 60 字快速框，直接打开 task_editor_sheet
  （默认 kind=oneOff，标题框自动聚焦），标题/类型/备注/定时提醒一次编完。
- 删除快速弹窗及其字符上限逻辑；编辑态 Edit/Done 与列表内点选编辑行为不变。

## 测试 seam（先红后绿）

- 022A：AppController 层（复用现有 controller 测试基建）——
  `adoptPreset(petId)` 领养后宠物架含该宠且 selected 切换；重复领养幂等；
  hatch 流程在无任何 gate 状态下可达（原 isUnlocked 分支删除后相关测试改写）。
  存量 gate 文件存在时启动不异常（app_state/store 层现有迁移测试处加一例）。
- 022B：现有 home_screen widget 测试处——点添加直接出现编辑面板、可一次设置
  标题+定时提醒并落库；旧快速弹窗测试删除。

## Out of Scope

- 不引入任何货币购宠/购内容机制；treat 经济、bond、furniture/food 定价不动。
- 不改 onboarding 流程与文案；老用户不重跑 onboarding。
- 报告（thesis/report*.html）改动不在卡内，由 Claude 侧并行处理。
- 后端部署、真 IAP、iOS widget 维持 ADR 0002 冻结。

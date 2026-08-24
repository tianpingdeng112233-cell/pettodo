# Pixel UI Restyle — Direction A "Cozy Pixel" (⚖️2026-08-24 David 拍板)

正典:设计画布 https://claude.ai/code/artifact/bcf1041c-4593-47a3-81f6-09cc0981a90b
(工作文件即本目录五块 `.dc.html`;方向 B「Full Retro」仅为对比存档,不实装)。
原则:**结构一比一,只换视觉语言**。导航/层级/文案/交互零改动;已有 44 测试零回归。

## Token 映射(lib/ui/theme/ 现值 → 像素处理)

| 现 token | 现值 | 像素化 |
|---|---|---|
| PetColors.* | 全部 | **不变**。调色板整套保留 |
| PetRadii.small/sprite/input/cardSmall/banner/card | 8–24 | 归零,换 **StairBorder**:大件(card/banner/sprite frame/按钮)= 12px 双阶(4px 步);小件(chip/input/badge/ground)= 4px 单阶 |
| PetRadii.pill | 999 | 消灭。pill 一律变单阶方角 |
| PetShadows.task/panel/petChoice | blur 14 | **硬阴影** offset(0,4) blur 0,色不变 |
| PetShadows.primaryButton | blur 16 | offset(0,4) blur 0,色改 rgba(185,107,46,.35) |
| PetShadows.banner/theaterButton/toggleKnob | — | 同法:blur 归零,offset 保留纵向 4 |
| PetTextStyles.display24–30/theaterLine | Baloo 2 | 家族改 **Pixelify Sans**(w600),字号不变;display30 的 letterSpacing 2 归 0 |
| PetTextStyles 其余 body/task/button/caption | system | 家族接 **Baloo 2**(ttf 已在 assets/fonts/,借此波正式接线 pubspec) |
| screenTop→screenBottom 渐变 | 保留 | 上面叠 **dither**:8px 棋盘 conic 图案,rgba(185,107,46,.035) |
| sunHalo | 柔和 radial | **硬 stop 分环**:.55/25% → .38/45% → .22/65% → .10/85% → 透明 |

## 组件规格(全部新建于 lib/ui/theme/ 或 lib/ui/widgets/)

- **StairBorder**(自定义 ShapeBorder):双阶 polygon 同设计稿 `.pc`,单阶同 `.ps`;是整波唯一有几何逻辑的新代码,配 path 单测。
- **PxCard**:外层 StairBorder 填充 #F4C9A0(=stroke)厚 2px + 内层白填充;选中态外层 primary 厚 3px。
- **PxButton** primary(primary 填充+白字+硬影)/ outline(#6B4A2B 2px 描边)。
- **PxCheckbox**:26px 方,3px 边 #F2C393;done= primary 填充 + 白像素勾(5 段阶梯)。
- **PxToggle**:54×30 方,knob 24px 方白。
- **PxChip/PxInput/ground bar**:单阶,现色。
- **像素图标**(settings 滑杆/sparkle/bone/heart/paw/egg/plus/minus/chevron/back):CustomPainter 矩形拼绘或导出 PNG,正典为设计稿内联 SVG。
- **Sprite 渲染**:FilterQuality 全部钉 **none**(含 Collection 缩略与 onboarding 行内),这是像素正典的一部分。

## 测试 seam(先红后绿)

1. 既有 44 widget/unit 测试 = 回归闸,不许改断言。
2. StairBorder path 单测(顶点序列断言)。
3. golden 快照:Home/Settings/Collection/Onboarding 四屏 iPhone 尺寸,对照设计稿收货。
4. 验收:模拟器四屏亲眼对版 + Android 真启动一次(07-22 纪律)。

## Out of Scope

- history/hatch_request/task_editor 三屏:同组件语言实装,不逐像素追稿(没画)。
- bundled 手绘 Choco 素材命运(待拍板,见会话)。绿边 despill、look 帧真产出、正典素材重出=素材流水线活,不进本 UI 卡。
- Task 002 常驻层(风格已定,素材形态=像素,解锁排队)。
- 动画帧时长/mesh 探针清理(PROPOSAL-009 作废归档,lib/dev/ 删除可顺手进卡)。

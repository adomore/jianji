# 简记 (JianJi) — iOS 实现

这是 Claude Design 交付包中 **《简记 UI 原型》** 的原生 iOS 实现。按 PRD（`project/uploads/记账App-PRD.md`）以 **Swift / SwiftUI / SwiftData** 构建，iOS 17+。

设计原型（`project/HomeScreen.dc.html`、`AddSheet.dc.html`）中定稿的两屏（明细首页、记账弹出页，浅/深色）被 **像素级复刻**；其余三屏（语音确认卡片、图表页、空状态）按 PRD 第 4、5 章在同一套设计语言下补齐。

## 如何打开 / 运行

1. 用 **Xcode 16+** 打开 `JianJi.xcodeproj`（macOS）。
2. 选择任意 iPhone 模拟器（如 iPhone 15），⌘R 运行。
3. App 显示名为「简记」；工程/产品名用 ASCII `JianJi`（避免 CJK 模块名问题）。

> 工程使用 Xcode 16 的 **file-system-synchronized group**：`JianJi/` 目录下的所有源文件会自动纳入编译，新增文件无需手动加进工程。

## 测试（⌘U）

`JianJiTests` 单元测试 target（已接入工程与 scheme，`@testable import JianJi`）：**6 个文件 / 41 个用例**，覆盖功能与性能。

| 文件 | 覆盖 |
|---|---|
| `AmountInputTests` | 键盘金额规则：前导零、双小数点、≤2 位小数、6 位整数上限与溢出、999999.99 边界、退格/清空、`set` 归一化 |
| `EntryParserTests` | 语音解析：金额（`25`/`18.5`/`23块5`）、今天/昨天/前天、关键词→分类、备注、PRD §4.3 三条验收（午饭 25 / 打车 / 无关话兜底）、收入工资 |
| `FormatterTests` | 千分位与两位小数、`¥`/正负号、周几/年月日、`0.1+0.2` 精度守卫 |
| `PersistenceTests` | 内存态 SwiftData：内置分类播种（12 条、幂等）、增查、删除分类 `.nullify`（账单不删）、月度汇总、按天分组 |
| `PerformanceTests` | `measure`：解析、格式化、键盘输入、千笔账月度聚合 |

> 本机（Linux）无 Xcode，无法在此执行；已做括号配平与工程结构校验，在 macOS 上 `⌘U` 可直接跑。

## 屏幕 ↔ PRD 对照

| 屏 | PRD | 文件 |
|---|---|---|
| ① 明细首页（月度卡片 + 按天分组列表 + 空状态） | §4.2 / §4.4-list | `Features/Home/*` |
| ② 记账弹出页（分段 / 分类网格 / 大字金额 / 4×4 键盘 / 🎤🖼） | §4.1 / §5.3 | `Features/Add/*` |
| ③ 语音 · 截图确认卡片（字段可改，绝不直接入库） | §4.3 / §4.4 | `Features/Voice/*` |
| ④ 图表页（三数字 + 甜甜圈 + 排行 + 每日柱状） | §4.5 | `Features/Charts/ChartsView.swift` |
| ⑤ 设置（分类管理 + 关于/隐私） | §4.6 / §5.1 | `Features/Settings/*` |

## 关键实现要点

- **金额全链路 `Decimal`**（PRD §9.3），显示走 `NumberFormatter`；键盘输入规则（≤2 位小数、≤999999.99、禁 0）在 `AmountInput.swift`，与原型 `tap()` 逻辑一致。
- **数据 SwiftData**：`Transaction` / `Category` 两张表（PRD §6.2），首次启动写入 8 支出 + 4 收入内置分类（`SeedData.swift`）。
- **语音**：`SFSpeechRecognizer(zh-CN)` + `AVAudioEngine`，优先本地识别；关键词规则解析金额/分类/日期（`EntryParser.swift`），失败自动退化为手填。
- **截图 OCR**：`PhotosPicker`（免相册权限）+ Vision `VNRecognizeTextRequest`（本地），取"最大字号的金额候选"，多张逐条确认。
- **主题**：`Theme.swift` 内联原型的精确色值（主色 `#FF9500` / 深色 `#FF9F0A`，收入绿 `#34C759` / `#30D158` 等），浅/深色两版。
- 权限文案在工程 `INFOPLIST_KEY_*`（麦克风 / 语音识别）；拒绝后有"去设置"引导。

## 打磨（发布版细节）

- **App 图标**：橙色渐变 + 白色 ¥，1024²（`Assets.xcassets/AppIcon`）。
- **无障碍**：图标型控件均有 VoiceOver 标签（悬浮 ＋ / 月份箭头 / 键盘 ⌫）。
- **动效**：新账单入列表淡入（§5.2.5）；键盘/分类/入口按钮按压缩放（复刻原型 `style-active`，见 `Support/PressableStyle.swift`）；保存成功触感反馈。
- **图表交互**：点甜甜圈扇区高亮该分类并在圆心显示金额（§4.5，`.chartAngleSelection`）。
- **安全区**：明细 / 图表用系统安全区自动避让状态栏（不再硬编码顶部间距）。
- **品牌启动屏**：橙底 `LaunchBackground` 色值 + 部分清单 `Configs/Info.plist`（`UILaunchScreen`）。清单放在同步分组外，避免被当资源重复打包；`GENERATE_INFOPLIST_FILE=YES` 仍生成并合并其余键。
- **超小屏**：记账页分类区放入弹性 `ScrollView`，空间不足时网格内部滚动，金额与键盘始终完整可见；参考机型 390×844 观感不变。

## 说明 / 边界

- Swift 语言模式设为 **5.0**（`SWIFT_VERSION`），可平滑切到 6.0；工程结构与 API 均按 iOS 17 编写。
- 语音 / OCR 需真机或模拟器授予权限方能实测；断网下 OCR 与文本记账照常工作。
- P2 项（预算 / 导出 CSV / iCloud）在设置页以"即将推出"占位，保持信息架构完整。
- 本仓库未做提交（未 `git commit`）；工程仅在本地。

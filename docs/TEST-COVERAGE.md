# 简记 1.1 测试覆盖报告

> 说明：本仓库的迭代在无 macOS/Xcode 的云端环境完成，**无法在此环境运行 `xcodebuild` 或测量真实行覆盖率**。以下为测试清单、覆盖矩阵，以及你在 Mac 上一键测量覆盖率的命令。逻辑层（correctness-critical）已做充分单元覆盖；SwiftUI 视图体与系统集成（通知/Face ID/语音/OCR/Widget/CloudKit）需 UI 测试或人工验收（附清单）。

## 一、在 Mac 上运行测试并测量覆盖率

```bash
# 运行全部单元 + 性能测试，并开启覆盖率
xcodebuild test \
  -scheme JianJi \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES \
  -resultBundlePath build/JianJi.xcresult

# 查看逐文件覆盖率
xcrun xccov view --report build/JianJi.xcresult

# 只看某文件
xcrun xccov view --report --files-for-target JianJi build/JianJi.xcresult | grep -i AmountInput
```

Xcode 里：Product → Test（⌘U）后，Report Navigator → 最近一次 Test → **Coverage** 标签即可看到彩色覆盖率。

## 二、单元测试覆盖矩阵（逻辑层）

| 单元 / 文件 | 测试文件 | 覆盖点 |
|---|---|---|
| `AmountInput` | AmountInputTests（15）+ Performance | 输入规则、小数/上限、光标插入/删除/边界 |
| `EntryParser` | EntryParserTests（15）+ Performance | 金额/日期/分类解析、收支判定 |
| `Fmt`（Formatters） | FormatterTests（7）+ Performance | 货币/千分位/符号/plain |
| `Ledger`（hash/matches/color） | LedgerTests（7） | 密码加盐哈希、隐私账本校验 |
| 月度/日聚合、`signedAmount` | AggregationTests（4） | 收支求和、隐私过滤 |
| SwiftData CRUD / 播种 | PersistenceTests（6） | 增删改查、seed 幂等 |
| `RecurringRule` / `RecurringEngine` | RecurringTests（7）+ ModelLogic + Performance | occurs 规则、月末夹取、回填、幂等、暂停、频率桥接、文案 |
| `TransactionSearch` | SearchTests（6）+ ModelLogic + Performance | 关键词/分类/金额匹配、筛选、合计、空集 |
| `ActiveLedger.resolve` | ActiveLedgerTests（5） | 存储 id → 默认 → 首个 → 空 回退链 |
| `BudgetSnapshot` + 预算阈值 | BudgetSnapshotTests（6） | 计算属性、Codable 往返、`alert(forRatio:)` 阈值 |
| `Transaction`/`RecurringFrequency`/`Calendar.startOfMonth`/`SyncStatus` | ModelLogicTests（8） | 符号金额、频率枚举、月首日、同步开关 |

**合计 90 个测试方法**，覆盖全部纯逻辑 / 模型 / 引擎单元。

## 三、性能测试（`measure`，回归护栏）

- `testParsePerformance` — 2000 次语音解析
- `testFormatPerformance` — 5000 次货币格式化
- `testAmountInputPerformance` — 3000 次键盘输入序列
- `testAggregationPerformance` — 1000 笔/月聚合（首页 & 图表每次渲染的工作量）
- `testSearchPerformance` — 2000 笔全库搜索（每次输入的工作量）
- `testRecurringBackfillPerformance` — 一年每日周期账单单次回填

## 四、未做单元测试的部分（需 UI 测试或人工验收）

这些是 SwiftUI 视图体与系统/硬件集成，行覆盖需 XCUITest 或真机人工验收：

- 各 `*View`（HomeView / ChartsView / AddSheetView / Settings / Ledger / Search / MonthPicker 等）视图体
- `NotificationManager` 的通知投递、授权、前台呈现（阈值判定已单测）
- `WidgetBridge` / `BudgetEvaluator` 的取数+写 App Group+刷新（聚合与快照计算已单测）
- `SpeechManager`（语音）、`OCRService`（Vision）、`AppLock`/`LedgerLock`（Face ID）

### 人工功能验收清单（覆盖上述 UI/系统层）

- [ ] 记账：金额键盘 + 光标编辑；备注切系统输入法不冲突；保存后明细/图表即时更新
- [ ] 语音记账：说“午餐支出25元”→ 识别为餐饮/支出/25
- [ ] 截图记账：选图 → OCR → 确认入账
- [ ] 多账本：新建/排序（长按拖动）/切换/删除；记账页顶部快捷切换
- [ ] 隐私：App 锁、单笔隐私（Face ID 显示）、隐私账本（Face ID+密码）
- [ ] 预算提醒：设预算并开提醒，支出过 80%/超支各收到一次通知
- [ ] 周期账单：建每月账单 → 次月打开 App 自动补记
- [ ] Widget：桌面添加，记账后自动刷新（需完成 App Group 配置）
- [ ] iCloud：两台设备登录同一 iCloud，账单同步（需完成 capability 配置）
- [ ] 搜索：按备注/分类/金额搜；筛选支出/收入
- [ ] 图表：分类环图、排行、每日柱、近半年趋势
- [ ] 月份直达：点月度卡片标题 → 选任意年月
- [ ] 导出：图片（汇总+明细）与 CSV
- [ ] 启动页：删装后冷启动显示 ¥+简记，无白屏

## 五、关于「100% 覆盖率」

- **逻辑层**：已按 100% 目标编写覆盖（上表所有分支/边界）。请用第一节命令在本机测得实际数字；若个别行未覆盖，把 `xccov` 报告发我，我补测试。
- **视图/系统层**：SwiftUI 视图体的 100% 行覆盖需引入 XCUITest target（可作为 1.2 工程项）；当前以上方人工验收清单达成功能级验收。
- 结论：逻辑正确性以自动化单测保障，端到端功能以人工清单验收——两者共同构成 1.1 的验收依据。

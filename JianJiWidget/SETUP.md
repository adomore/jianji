# 简记 · 桌面小组件接入步骤（Widget）

小组件是独立的 App Extension target，无法用文件同步组自动纳入，需要在 Xcode 里手动建一次。约 5 分钟。

主 App 侧代码已写好并接线（`BudgetSnapshot` / `WidgetBridge`，记账、启动、回前台时自动刷新快照）。你只需完成下面的 Xcode 配置。

## 1. 新建 Widget Extension target
1. Xcode 菜单 **File → New → Target…**
2. 选 **Widget Extension**，Next。
3. Product Name 填 **`JianJiWidget`**；**取消勾选** “Include Live Activity” 和 “Include Configuration App Intent”（用静态配置）。
4. Finish → 弹窗点 **Activate**。

## 2. 用提供的源码替换自动生成的文件
1. Xcode 自动生成了 `JianJiWidget/JianJiWidget.swift`（含 `@main`）等文件，把它们**删除**（Move to Trash）。
2. 把本目录的 **`JianJiWidget.swift`** 和 **`JianJiWidgetBundle.swift`** 拖进 Xcode 的 `JianJiWidget` 组，勾选 **只加入 JianJiWidget target**。

## 3. 共享快照文件加入两个 target
1. 在 Project Navigator 选中 **`JianJi/Support/BudgetSnapshot.swift`**。
2. 右侧 File Inspector → **Target Membership**，同时勾选 **JianJi** 和 **JianJiWidget** 两个 target。
   （这样 App 和 Widget 用的是同一个 `BudgetSnapshot` 结构。）

## 4. 加 App Group（两个 target 都要）
对 **JianJi** 和 **JianJiWidget** 各做一次：
1. 选中 target → **Signing & Capabilities** → 左上 **+ Capability** → **App Groups**。
2. 点 **+**，添加组 **`group.com.jianji.app`**（必须和 `BudgetSnapshot.appGroup` 一致）。

> 若你想用别的组名，改 `BudgetSnapshot.swift` 里的 `appGroup` 常量，保持三处一致即可。

## 5. 编译运行
- 选 **JianJi** scheme 运行到真机，记几笔。
- 长按桌面 → 添加小组件 → 找 **简记** → 选小号/中号。
- 记一笔或回到前台后，小组件会自动刷新（`WidgetCenter.reloadAllTimelines`）。

## 说明
- Widget 只读一份轻量快照（本月支出/收入/预算），**不共享 SwiftData 库**，无数据迁移风险。
- **隐私账单不写入快照**，不会出现在桌面。
- 未完成上述配置前，主 App 一切正常——`WidgetBridge` 写入一个 Widget 暂时读不到的私有 suite，无副作用。

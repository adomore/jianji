# 简记 · iCloud 同步接入步骤

代码已就绪：`JianJiApp` 会**优先用 CloudKit 打开数据库，失败则回退本地**——所以不配置也能正常跑，配置后自动生效，现有本地账单会一并上传。你只需在 Xcode 完成能力配置。

## 前置检查（已满足）
- 所有 `@Model` 属性都有默认值 ✅
- 关系可选（`Ledger.transactions` 有 inverse）✅
- 无 `@Attribute(.unique)` 约束 ✅

这三条是 SwiftData + CloudKit 的硬性要求，当前模型均已满足。

## Xcode 配置
选中 **JianJi** target → **Signing & Capabilities**：

1. **+ Capability → iCloud**
   - 勾选 **CloudKit**
   - 在 Containers 里 **+** 添加 `iCloud.com.jianji.app`
   （容器名可自定义，`.automatic` 会自动选取工程里配置的那个）
2. **+ Capability → Background Modes**
   - 勾选 **Remote notifications**（CloudKit 静默推送用于增量同步）
3. 确保 **Signing** 用的是你已启用 iCloud 的开发者账号。

## 验证
1. 真机 A 登录 iCloud → 运行简记 → 记几笔。
2. 真机 B 同一 Apple ID → 运行简记 → 稍等，账单出现。
3. 设置 → iCloud 同步，状态显示 **已开启**。

## 说明
- 同步走系统 iCloud **私有库（CloudKit private database）**，数据只在用户 Apple ID 内，简记无服务器、不收集数据。
- 首次开启时，本机已有账单会上传到 iCloud；卸载重装后可从 iCloud 恢复。
- 若容器创建因 CloudKit 不可用而失败，App 自动回退本地存储，不会崩溃（设置里状态显示「未启用」）。
- **不涉及任何账号登录/注册**——完全依赖系统 iCloud 账号，符合 1.2 前不做账号体系的约束。

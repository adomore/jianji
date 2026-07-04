import SwiftUI
import SwiftData

@main
struct JianJiApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Transaction.self, Category.self, Ledger.self, RecurringRule.self])
        // Try CloudKit-backed sync first; if the iCloud capability/entitlement isn't present
        // (or CloudKit is unavailable) the config throws and we fall back to a local-only store.
        // So this same binary runs fine with OR without iCloud enabled — enabling the capability
        // in Xcode switches sync on with zero code change, and existing local data migrates up.
        if let cloud = try? ModelContainer(for: schema,
                                           configurations: ModelConfiguration(schema: schema,
                                                                              cloudKitDatabase: .automatic)) {
            container = cloud
            SyncStatus.iCloudActive = true
        } else {
            do {
                container = try ModelContainer(for: schema,
                                               configurations: ModelConfiguration(schema: schema))
            } catch {
                fatalError("无法创建 SwiftData 容器: \(error)")
            }
        }
        // Seed built-in categories + default 账本 on first launch (ledger seeding also
        // migrates existing installs by assigning ledger-less bills to the default book).
        SeedData.seedIfNeeded(container.mainContext)
        SeedData.seedLedgerIfNeeded(container.mainContext)
        // Post any recurring bills (周期账单) that came due while the app was closed.
        RecurringEngine.materialize(container.mainContext)
        // Local notifications: allow foreground banners + check the budget threshold.
        NotificationManager.shared.configure()
        BudgetEvaluator.run(container.mainContext)
        WidgetBridge.update(container.mainContext)   // 刷新桌面小组件快照
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

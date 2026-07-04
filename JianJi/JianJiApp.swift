import SwiftUI
import SwiftData

@main
struct JianJiApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Transaction.self, Category.self, Ledger.self)
        } catch {
            fatalError("无法创建 SwiftData 容器: \(error)")
        }
        // Seed built-in categories + default 账本 on first launch (ledger seeding also
        // migrates existing installs by assigning ledger-less bills to the default book).
        SeedData.seedIfNeeded(container.mainContext)
        SeedData.seedLedgerIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

import SwiftUI
import SwiftData

@main
struct JianJiApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Transaction.self, Category.self)
        } catch {
            fatalError("无法创建 SwiftData 容器: \(error)")
        }
        // Seed built-in categories on first launch.
        SeedData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

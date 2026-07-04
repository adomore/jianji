import Foundation

/// Lightweight month summary the main app writes into the shared App Group so the Home-screen
/// Widget can render without opening the SwiftData store (no store sharing, no data migration).
///
/// SHARED FILE — this one file must belong to BOTH targets: the app *and* the widget extension
/// (tick both in File Inspector → Target Membership).
struct BudgetSnapshot: Codable {
    var monthLabel: String      // e.g. "2026年7月"
    var ledgerName: String
    var expense: Double
    var income: Double
    var budget: Double          // 0 = 不限
    var updatedAt: Date

    /// App Group id — must match the App Group added to both targets' Signing & Capabilities.
    static let appGroup = "group.com.jianji.app"
    static let key = "widget.snapshot.v1"

    static var placeholder: BudgetSnapshot {
        BudgetSnapshot(monthLabel: "本月", ledgerName: "默认账本",
                       expense: 1280, income: 8000, budget: 3000, updatedAt: Date())
    }

    /// Read the latest snapshot from shared defaults (used by the widget timeline provider).
    static func load() -> BudgetSnapshot? {
        guard let d = UserDefaults(suiteName: appGroup),
              let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BudgetSnapshot.self, from: data)
    }

    var remaining: Double { budget - expense }
    var overBudget: Bool { budget > 0 && expense > budget }
    var ratio: Double { budget > 0 ? min(1, max(0, expense / budget)) : 0 }
}

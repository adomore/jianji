import Foundation

/// Resolves the currently active 账本 from the stored id, with safe fallbacks
/// (stored book → default book → first book). Shared by 首页 / 图表 / 记账 / 账本.
enum ActiveLedger {
    static let storageKey = "activeLedgerID"

    static func resolve(_ ledgers: [Ledger], activeID: String) -> Ledger? {
        ledgers.first { $0.id.uuidString == activeID }
            ?? ledgers.first { $0.isDefault }
            ?? ledgers.first
    }
}

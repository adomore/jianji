import Foundation
import SwiftData

/// Built-in categories inserted on first launch. PRD §4.6.
///
/// Colors & tint opacities are copied verbatim from the prototype's `tint()` map so the
/// icon chips render identically. Emoji match the mockup; SF Symbol names are the PRD's
/// suggested equivalents (kept for a future symbol/emoji toggle).
enum SeedData {

    struct Def {
        let name: String
        let emoji: String
        let symbol: String
        let hex: String
        let tint: Double
    }

    // 支出：🍜餐饮、🚇交通、🛍购物、🧻日用、🎮娱乐、💊医疗、🏠住房、📦其他
    static let expense: [Def] = [
        .init(name: "餐饮", emoji: "🍜", symbol: "fork.knife",           hex: "FF9500", tint: 0.16),
        .init(name: "交通", emoji: "🚇", symbol: "tram.fill",            hex: "007AFF", tint: 0.15),
        .init(name: "购物", emoji: "🛍️", symbol: "bag.fill",             hex: "FF2D55", tint: 0.13),
        .init(name: "日用", emoji: "🧻", symbol: "cart.fill",            hex: "30B0C7", tint: 0.16),
        .init(name: "娱乐", emoji: "🎮", symbol: "gamecontroller.fill",  hex: "AF52DE", tint: 0.15),
        .init(name: "医疗", emoji: "💊", symbol: "cross.case.fill",      hex: "FF3B30", tint: 0.13),
        .init(name: "住房", emoji: "🏠", symbol: "house.fill",           hex: "5856D6", tint: 0.15),
        .init(name: "其他", emoji: "📦", symbol: "shippingbox.fill",     hex: "787880", tint: 0.16),
    ]

    // 收入：💰工资、🧧红包、📈理财、📦其他
    static let income: [Def] = [
        .init(name: "工资", emoji: "💰", symbol: "yensign.circle.fill",  hex: "34C759", tint: 0.16),
        .init(name: "红包", emoji: "🧧", symbol: "gift.fill",            hex: "FF3B30", tint: 0.13),
        .init(name: "理财", emoji: "📈", symbol: "chart.line.uptrend.xyaxis", hex: "00C7BE", tint: 0.16),
        .init(name: "其他", emoji: "📦", symbol: "shippingbox.fill",     hex: "787880", tint: 0.16),
    ]

    /// Insert built-in categories once, if the store is empty.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<Category>())
        guard (existing?.isEmpty ?? true) else { return }

        var order = 0
        func insert(_ defs: [Def], isExpense: Bool) {
            for d in defs {
                let c = Category(name: d.name, emoji: d.emoji, symbolName: d.symbol,
                                 colorHex: d.hex, tintOpacity: d.tint,
                                 isExpense: isExpense, sortOrder: order, isBuiltin: true)
                context.insert(c)
                order += 1
            }
        }
        insert(expense, isExpense: true)
        insert(income, isExpense: false)
        try? context.save()
    }

    /// Ensure a default 账本 exists and every ledger-less bill is assigned to it.
    /// Idempotent — safe to run on every launch so existing installs migrate cleanly.
    static func seedLedgerIfNeeded(_ context: ModelContext) {
        let ledgers = (try? context.fetch(FetchDescriptor<Ledger>())) ?? []
        let defaultLedger: Ledger
        if let existing = ledgers.first(where: { $0.isDefault }) ?? ledgers.first {
            defaultLedger = existing
        } else {
            let l = Ledger(name: "默认账本", symbolName: "books.vertical.fill",
                           colorHex: "FF9500", isDefault: true, sortOrder: 0)
            context.insert(l)
            defaultLedger = l
        }
        // Reassign orphan bills (created before multi-ledger existed) to the default book.
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in all where tx.ledger == nil { tx.ledger = defaultLedger }
        try? context.save()
    }
}

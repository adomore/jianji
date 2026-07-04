import Foundation
import SwiftData
import WidgetKit

/// Writes the current-month `BudgetSnapshot` for the active book into the shared App Group and
/// asks WidgetKit to reload. Safe to call before the App Group is configured — it simply writes
/// to a private suite the widget can't see yet (no crash), so wiring it in advance is harmless.
///
/// Private bills are excluded so the Home-screen widget never surfaces hidden spending.
enum WidgetBridge {
    static func update(_ context: ModelContext) {
        let d = UserDefaults.standard
        let budget = d.double(forKey: "monthlyBudget")
        let activeID = d.string(forKey: ActiveLedger.storageKey) ?? ""

        let cal = Calendar.current
        let ledgers = (try? context.fetch(FetchDescriptor<Ledger>())) ?? []
        let active = ActiveLedger.resolve(ledgers, activeID: activeID)
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let monthBills = all.filter {
            !$0.isPrivate && $0.ledger?.id == active?.id
            && cal.isDate($0.date, equalTo: .now, toGranularity: .month)
        }
        let expense = monthBills.filter { $0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        let income  = monthBills.filter { !$0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }

        let snap = BudgetSnapshot(
            monthLabel: Fmt.yearMonth(Date()),
            ledgerName: active?.name ?? "默认账本",
            expense: (expense as NSDecimalNumber).doubleValue,
            income: (income as NSDecimalNumber).doubleValue,
            budget: budget,
            updatedAt: Date())

        if let data = try? JSONEncoder().encode(snap),
           let shared = UserDefaults(suiteName: BudgetSnapshot.appGroup) {
            shared.set(data, forKey: BudgetSnapshot.key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

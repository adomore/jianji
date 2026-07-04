import Foundation

/// Pure, testable filtering for 账单搜索. Kept out of the view so it can be unit-tested and
/// reused. Matching is case-insensitive across category name, note, and the plain amount string.
enum TransactionSearch {
    enum Kind: Hashable { case all, expense, income }

    /// Filter `bills` by free-text `query` and income/expense `kind`. `bills` is assumed to be
    /// already scoped to the active book + privacy (the caller does that).
    static func filter(_ bills: [Transaction], query: String, kind: Kind) -> [Transaction] {
        let byKind = bills.filter { tx in
            switch kind {
            case .all:     return true
            case .expense: return tx.isExpense
            case .income:  return !tx.isExpense
            }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return byKind }
        return byKind.filter { tx in
            if let name = tx.category?.name, name.localizedCaseInsensitiveContains(q) { return true }
            if tx.note.localizedCaseInsensitiveContains(q) { return true }
            if Fmt.plain(tx.amount).contains(q) { return true }
            return false
        }
    }

    static func totals(_ bills: [Transaction]) -> (expense: Decimal, income: Decimal) {
        let e = bills.filter { $0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        let i = bills.filter { !$0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        return (e, i)
    }
}

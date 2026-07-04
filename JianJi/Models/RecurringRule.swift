import Foundation
import SwiftData

/// How often a recurring bill repeats.
enum RecurringFrequency: String, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily:   return "每天"
        case .weekly:  return "每周"
        case .monthly: return "每月"
        }
    }
}

/// A template that auto-creates a `Transaction` on a schedule (周期账单 / 定期记账).
///
/// No timers or background tasks — occurrences are *materialized* lazily: whenever the app
/// launches or returns to the foreground, `RecurringEngine` inserts any bills that came due
/// since `lastRun`. This survives the app being closed for days and needs no server.
///
/// Every stored property has a default so SwiftData can lightweight-migrate an existing
/// store (same convention as the other @Model types here).
@Model
final class RecurringRule {
    var id: UUID = UUID()
    var amount: Decimal = 0            // always positive; sign from isExpense
    var isExpense: Bool = true
    var category: Category?
    var ledger: Ledger?
    var note: String = ""
    var isPrivate: Bool = false
    var frequencyRaw: String = RecurringFrequency.monthly.rawValue
    /// Monthly → day-of-month (1...31, clamped to month length). Weekly → weekday (1=Sun...7=Sat).
    /// Ignored for daily.
    var anchorDay: Int = 1
    var startDate: Date = Date()
    var lastRun: Date?                 // start-of-day of the most recent materialized occurrence
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(amount: Decimal,
         isExpense: Bool,
         category: Category?,
         ledger: Ledger?,
         note: String = "",
         isPrivate: Bool = false,
         frequency: RecurringFrequency = .monthly,
         anchorDay: Int = 1,
         startDate: Date = .now) {
        self.amount = amount
        self.isExpense = isExpense
        self.category = category
        self.ledger = ledger
        self.note = note
        self.isPrivate = isPrivate
        self.frequencyRaw = frequency.rawValue
        self.anchorDay = anchorDay
        self.startDate = startDate
        self.createdAt = .now
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Whether an occurrence falls on the given day (compared at day granularity).
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let d = calendar.startOfDay(for: day)
        guard d >= calendar.startOfDay(for: startDate) else { return false }
        switch frequency {
        case .daily:
            return true
        case .weekly:
            return calendar.component(.weekday, from: d) == anchorDay
        case .monthly:
            let dim = calendar.range(of: .day, in: .month, for: d)?.count ?? 28
            let target = min(max(1, anchorDay), dim)   // clamp e.g. 31 → 30 / Feb 28
            return calendar.component(.day, from: d) == target
        }
    }

    /// Human-readable cadence, e.g. "每月 15 日" / "每周 三" / "每天".
    var scheduleText: String {
        switch frequency {
        case .daily:
            return "每天"
        case .weekly:
            let names = ["日", "一", "二", "三", "四", "五", "六"]
            let idx = min(max(1, anchorDay), 7) - 1
            return "每周" + names[idx]
        case .monthly:
            return "每月 \(min(max(1, anchorDay), 31)) 日"
        }
    }
}

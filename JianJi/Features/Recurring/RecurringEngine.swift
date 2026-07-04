import Foundation
import SwiftData

/// Materializes due `RecurringRule`s into real `Transaction`s.
///
/// Called at cold launch and whenever the app returns to the foreground. Idempotent: each
/// rule only ever emits occurrences newer than its `lastRun`, so running it repeatedly (or
/// after the app was closed for a week) never double-charges.
enum RecurringEngine {

    /// Safety cap on how many days a single rule may back-fill in one pass, so a rule with a
    /// far-past `startDate` can't insert thousands of bills or spin. ~2 years of daily.
    private static let maxScanDays = 750

    @discardableResult
    static func materialize(_ context: ModelContext,
                            now: Date = .now,
                            calendar: Calendar = .current) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        let today = calendar.startOfDay(for: now)
        var inserted = 0

        for rule in rules where rule.isActive {
            // Scan from the day after the last materialized occurrence, or from the rule's
            // start date if it has never run.
            let from: Date
            if let last = rule.lastRun {
                from = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) ?? today
            } else {
                from = calendar.startOfDay(for: rule.startDate)
            }

            var occurrences: [Date] = []
            var day = from
            var steps = 0
            while day <= today && steps < maxScanDays {
                if rule.occurs(on: day, calendar: calendar) { occurrences.append(day) }
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
                steps += 1
            }

            for occ in occurrences {
                let tx = Transaction(amount: rule.amount,
                                     isExpense: rule.isExpense,
                                     category: rule.category,
                                     date: occ,
                                     note: rule.note,
                                     source: .manual,
                                     rawText: nil,
                                     ledger: rule.ledger,
                                     isPrivate: rule.isPrivate)
                context.insert(tx)
                inserted += 1
            }
            if let last = occurrences.last { rule.lastRun = last }
        }

        if inserted > 0 { try? context.save() }
        return inserted
    }
}

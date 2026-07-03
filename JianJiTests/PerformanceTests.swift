import XCTest
import SwiftData
@testable import JianJi

/// Performance coverage (XCTest `measure`). These guard against regressions in the
/// hot paths: keypad input, parsing, currency formatting, and month aggregation.
@MainActor
final class PerformanceTests: XCTestCase {

    func testParsePerformance() {
        let phrases = ["午饭花了25", "昨天打车23块", "买奶茶18.5", "今天天气不错", "发工资8000"]
        measure {
            for i in 0..<2000 {
                let p = phrases[i % phrases.count]
                _ = EntryParser.parseAmount(p)
                _ = EntryParser.parseDate(p)
            }
        }
    }

    func testFormatPerformance() {
        measure {
            for i in 0..<5000 {
                _ = Fmt.money(Decimal(i) + Decimal(string: "0.5")!)
            }
        }
    }

    func testAmountInputPerformance() {
        let keys = ["1", "2", "3", ".", "4", "5", "⌫"]
        measure {
            for _ in 0..<3000 {
                var a = AmountInput()
                for k in keys { a.tap(k) }
                _ = a.decimalValue
            }
        }
    }

    /// Aggregating a full month of ~1000 bills — the work Home & Charts do on every render.
    @MainActor
    func testAggregationPerformance() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let expenseCats = try TestSupport.categories(c).filter { $0.isExpense }
        let base = TestSupport.date(2026, 7, 1)
        let cal = Calendar.current
        for i in 0..<1000 {
            let day = cal.date(byAdding: .day, value: i % 28, to: base)!
            ctx.insert(Transaction(amount: Decimal(i % 500) + 1, isExpense: true,
                                   category: expenseCats[i % expenseCats.count], date: day))
        }
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())

        measure {
            let inMonth = all.filter { cal.isDate($0.date, equalTo: base, toGranularity: .month) }
            let byDay = Dictionary(grouping: inMonth) { cal.startOfDay(for: $0.date) }
            var total = Decimal(0)
            for (_, txs) in byDay {
                total += txs.reduce(Decimal(0)) { $0 + $1.amount }
            }
            XCTAssertGreaterThan(total, 0)
        }
    }
}

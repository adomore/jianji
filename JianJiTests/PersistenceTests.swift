import XCTest
import SwiftData
@testable import JianJi

/// Functional coverage of the SwiftData layer: seeding, insert/fetch, the .nullify
/// delete rule, and the month/day aggregation the Home & Charts screens rely on.
@MainActor
final class PersistenceTests: XCTestCase {

    func testSeedInsertsBuiltins() throws {           // PRD §4.6
        let cats = try TestSupport.categories(TestSupport.makeSeededContainer())
        XCTAssertEqual(cats.count, 12)
        XCTAssertEqual(cats.filter { $0.isExpense }.count, 8)
        XCTAssertEqual(cats.filter { !$0.isExpense }.count, 4)
        XCTAssertTrue(cats.allSatisfy { $0.isBuiltin })
        XCTAssertEqual(cats.first?.name, "餐饮")        // sortOrder 0
    }

    func testSeedIsIdempotent() throws {
        let c = try TestSupport.makeSeededContainer()
        SeedData.seedIfNeeded(c.mainContext)          // second call must not duplicate
        XCTAssertEqual(try TestSupport.categories(c).count, 12)
    }

    func testInsertAndFetch() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        ctx.insert(Transaction(amount: 25, isExpense: true, category: food, note: "午饭"))
        try ctx.save()

        let txs = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        XCTAssertEqual(txs[0].amount, 25)
        XCTAssertEqual(txs[0].category?.name, "餐饮")
        XCTAssertEqual(txs[0].source, EntrySource.manual.rawValue)
    }

    func testDeleteCategoryNullifiesTransaction() throws {
        // Model contract is .nullify: deleting a category must NOT delete its bills.
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        let tx = Transaction(amount: 25, isExpense: true, category: food)
        ctx.insert(tx)
        try ctx.save()

        ctx.delete(food)
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 1)
        XCTAssertNil(tx.category)
    }

    func testMonthAggregation() throws {              // PRD §4.4 月度汇总
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let cats = try TestSupport.categories(c)
        let food = cats.first { $0.isExpense && $0.name == "餐饮" }!
        let salary = cats.first { !$0.isExpense && $0.name == "工资" }!
        let july = TestSupport.date(2026, 7, 4)

        ctx.insert(Transaction(amount: 25, isExpense: true, category: food, date: july))
        ctx.insert(Transaction(amount: Decimal(string: "8.5")!, isExpense: true, category: food, date: july))
        ctx.insert(Transaction(amount: 8000, isExpense: false, category: salary, date: july))
        // different month → must be excluded from July totals
        ctx.insert(Transaction(amount: 999, isExpense: true, category: food, date: TestSupport.date(2026, 6, 1)))
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let cal = Calendar.current
        let inJuly = all.filter { cal.isDate($0.date, equalTo: july, toGranularity: .month) }
        let expense = inJuly.filter { $0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        let income = inJuly.filter { !$0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }

        XCTAssertEqual(expense, Decimal(string: "33.5"))
        XCTAssertEqual(income, 8000)
        XCTAssertEqual(income - expense, Decimal(string: "7966.5"))
    }

    func testDayGrouping() throws {                   // PRD §4.2 按天分组
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        ctx.insert(Transaction(amount: 25, isExpense: true, category: food, date: TestSupport.date(2026, 7, 4)))
        ctx.insert(Transaction(amount: 10, isExpense: true, category: food, date: TestSupport.date(2026, 7, 4)))
        ctx.insert(Transaction(amount: 42, isExpense: true, category: food, date: TestSupport.date(2026, 7, 3)))
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let cal = Calendar.current
        let byDay = Dictionary(grouping: all) { cal.startOfDay(for: $0.date) }
        XCTAssertEqual(byDay.count, 2)                 // two distinct days
        let jul4 = byDay[cal.startOfDay(for: TestSupport.date(2026, 7, 4))]
        XCTAssertEqual(jul4?.count, 2)
    }
}

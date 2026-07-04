import XCTest
import SwiftData
@testable import JianJi

/// Coverage for the aggregation logic shared by 首页 / 图表 / 账本 overview.
@MainActor
final class AggregationTests: XCTestCase {

    func testSignedAmount() {
        XCTAssertEqual(Transaction(amount: 25, isExpense: true, category: nil).signedAmount, -25)
        XCTAssertEqual(Transaction(amount: 8000, isExpense: false, category: nil).signedAmount, 8000)
    }

    func testAllTimeTotals() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let cats = try TestSupport.categories(c)
        let food = cats.first { $0.isExpense && $0.name == "餐饮" }!
        let salary = cats.first { !$0.isExpense && $0.name == "工资" }!
        // spread across two months — all-time totals ignore the month
        ctx.insert(Transaction(amount: 25, isExpense: true, category: food, date: TestSupport.date(2026, 7, 4)))
        ctx.insert(Transaction(amount: 100, isExpense: true, category: food, date: TestSupport.date(2026, 6, 1)))
        ctx.insert(Transaction(amount: 8000, isExpense: false, category: salary, date: TestSupport.date(2026, 7, 2)))
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let income = all.filter { !$0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        let expense = all.filter { $0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        XCTAssertEqual(income, 8000)
        XCTAssertEqual(expense, 125)
        XCTAssertEqual(income - expense, 7875)   // 账本页 all-time 结余
    }

    func testNegativeBalance() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        ctx.insert(Transaction(amount: 500, isExpense: true, category: food, date: TestSupport.date(2026, 7, 4)))
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        let balance = all.filter { !$0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
                    - all.filter { $0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        XCTAssertTrue(balance < 0)              // 触发结余红胶囊
        XCTAssertEqual(balance, -500)
    }
}

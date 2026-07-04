import XCTest
import SwiftData
@testable import JianJi

/// Coverage for 账单搜索 pure filter logic (1.1 core).
@MainActor
final class SearchTests: XCTestCase {

    private func fixture() throws -> (bills: [Transaction], food: JianJi.Category, salary: JianJi.Category) {
        let container = try TestSupport.makeSeededContainer()
        let cats = try TestSupport.categories(container)
        let food = cats.first { $0.name == "餐饮" }!
        let salary = cats.first { $0.name == "工资" }!
        let ctx = container.mainContext
        let t1 = Transaction(amount: 25, isExpense: true, category: food, note: "楼下午餐")
        let t2 = Transaction(amount: 8000, isExpense: false, category: salary, note: "六月工资")
        let t3 = Transaction(amount: 300, isExpense: true, category: food, note: "请客吃饭")
        [t1, t2, t3].forEach { ctx.insert($0) }
        return ([t1, t2, t3], food, salary)
    }

    func testFilterByKind() throws {
        let f = try fixture()
        XCTAssertEqual(TransactionSearch.filter(f.bills, query: "", kind: .all).count, 3)
        XCTAssertEqual(TransactionSearch.filter(f.bills, query: "", kind: .expense).count, 2)
        XCTAssertEqual(TransactionSearch.filter(f.bills, query: "", kind: .income).count, 1)
    }

    func testSearchByNote() throws {
        let f = try fixture()
        let r = TransactionSearch.filter(f.bills, query: "午餐", kind: .all)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.note, "楼下午餐")
    }

    func testSearchByCategoryName() throws {
        let f = try fixture()
        // "餐饮" matches both food bills by category name.
        XCTAssertEqual(TransactionSearch.filter(f.bills, query: "餐饮", kind: .all).count, 2)
    }

    func testSearchByAmount() throws {
        let f = try fixture()
        let r = TransactionSearch.filter(f.bills, query: "8000", kind: .all)
        XCTAssertEqual(r.count, 1)
        XCTAssertFalse(r.first!.isExpense)
    }

    func testKindAndQueryCombine() throws {
        let f = try fixture()
        // "餐饮" matches 2 bills but restricting to income yields none.
        XCTAssertEqual(TransactionSearch.filter(f.bills, query: "餐饮", kind: .income).count, 0)
    }

    func testTotals() throws {
        let f = try fixture()
        let all = TransactionSearch.filter(f.bills, query: "", kind: .all)
        let totals = TransactionSearch.totals(all)
        XCTAssertEqual(totals.expense, 325)   // 25 + 300
        XCTAssertEqual(totals.income, 8000)
    }
}

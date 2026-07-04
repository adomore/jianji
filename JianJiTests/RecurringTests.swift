import XCTest
import SwiftData
@testable import JianJi

/// Coverage for 周期账单 — occurrence rules + lazy materialization (1.1).
@MainActor
final class RecurringTests: XCTestCase {

    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    private func txCount(_ c: ModelContainer) throws -> Int {
        try c.mainContext.fetch(FetchDescriptor<Transaction>()).count
    }

    // MARK: occurs(on:)

    func testMonthlyOccursOnAnchorDay() {
        let r = RecurringRule(amount: 100, isExpense: true, category: nil, ledger: nil,
                              frequency: .monthly, anchorDay: 15,
                              startDate: TestSupport.date(2026, 1, 1))
        XCTAssertTrue(r.occurs(on: TestSupport.date(2026, 3, 15), calendar: cal()))
        XCTAssertFalse(r.occurs(on: TestSupport.date(2026, 3, 14), calendar: cal()))
    }

    func testMonthlyDay31ClampsToMonthEnd() {
        let r = RecurringRule(amount: 100, isExpense: true, category: nil, ledger: nil,
                              frequency: .monthly, anchorDay: 31,
                              startDate: TestSupport.date(2026, 1, 1))
        // February 2026 has 28 days → the 28th is the occurrence.
        XCTAssertTrue(r.occurs(on: TestSupport.date(2026, 2, 28), calendar: cal()))
        XCTAssertFalse(r.occurs(on: TestSupport.date(2026, 2, 27), calendar: cal()))
    }

    func testWeeklyOccursOnWeekday() {
        // 2026-07-04 is a Saturday (weekday 7).
        let r = RecurringRule(amount: 50, isExpense: true, category: nil, ledger: nil,
                              frequency: .weekly, anchorDay: 7,
                              startDate: TestSupport.date(2026, 7, 1))
        XCTAssertTrue(r.occurs(on: TestSupport.date(2026, 7, 4), calendar: cal()))
        XCTAssertFalse(r.occurs(on: TestSupport.date(2026, 7, 5), calendar: cal()))
    }

    func testDoesNotOccurBeforeStartDate() {
        let r = RecurringRule(amount: 100, isExpense: true, category: nil, ledger: nil,
                              frequency: .daily, startDate: TestSupport.date(2026, 6, 1))
        XCTAssertFalse(r.occurs(on: TestSupport.date(2026, 5, 31), calendar: cal()))
        XCTAssertTrue(r.occurs(on: TestSupport.date(2026, 6, 1), calendar: cal()))
    }

    // MARK: materialize

    func testMaterializeBackfillsMissedMonthly() throws {
        let container = try TestSupport.makeSeededContainer()
        let ctx = container.mainContext
        let r = RecurringRule(amount: 3000, isExpense: true,
                              category: try TestSupport.categories(container).first,
                              ledger: try TestSupport.ledgers(container).first,
                              frequency: .monthly, anchorDay: 1,
                              startDate: TestSupport.date(2026, 1, 1))
        ctx.insert(r)
        try ctx.save()
        let before = try txCount(container)

        // Run "as of" April 10 → occurrences on Jan 1, Feb 1, Mar 1, Apr 1 = 4 bills.
        let n = RecurringEngine.materialize(ctx, now: TestSupport.date(2026, 4, 10), calendar: cal())
        XCTAssertEqual(n, 4)
        XCTAssertEqual(try txCount(container), before + 4)
    }

    func testMaterializeIsIdempotent() throws {
        let container = try TestSupport.makeSeededContainer()
        let ctx = container.mainContext
        let r = RecurringRule(amount: 100, isExpense: true,
                              category: try TestSupport.categories(container).first,
                              ledger: try TestSupport.ledgers(container).first,
                              frequency: .monthly, anchorDay: 1,
                              startDate: TestSupport.date(2026, 1, 1))
        ctx.insert(r)
        try ctx.save()

        let asOf = TestSupport.date(2026, 4, 10)
        _ = RecurringEngine.materialize(ctx, now: asOf, calendar: cal())
        let after1 = try txCount(container)
        // Second run at the same instant must add nothing (no double-charge).
        let n2 = RecurringEngine.materialize(ctx, now: asOf, calendar: cal())
        XCTAssertEqual(n2, 0)
        XCTAssertEqual(try txCount(container), after1)
    }

    func testPausedRuleDoesNotMaterialize() throws {
        let container = try TestSupport.makeSeededContainer()
        let ctx = container.mainContext
        let r = RecurringRule(amount: 100, isExpense: true,
                              category: try TestSupport.categories(container).first,
                              ledger: try TestSupport.ledgers(container).first,
                              frequency: .daily, startDate: TestSupport.date(2026, 1, 1))
        r.isActive = false
        ctx.insert(r)
        try ctx.save()
        let n = RecurringEngine.materialize(ctx, now: TestSupport.date(2026, 1, 10), calendar: cal())
        XCTAssertEqual(n, 0)
    }
}

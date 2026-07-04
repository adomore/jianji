import XCTest
@testable import JianJi

/// Small pure-logic units across models/helpers that lacked direct coverage.
@MainActor
final class ModelLogicTests: XCTestCase {

    // MARK: Transaction

    func testSignedAmount() {
        let expense = Transaction(amount: 25, isExpense: true, category: nil)
        let income = Transaction(amount: 8000, isExpense: false, category: nil)
        XCTAssertEqual(expense.signedAmount, -25)
        XCTAssertEqual(income.signedAmount, 8000)
    }

    // MARK: RecurringRule

    func testFrequencyBridgesRawValue() {
        let r = RecurringRule(amount: 1, isExpense: true, category: nil, ledger: nil, frequency: .weekly, anchorDay: 3)
        XCTAssertEqual(r.frequencyRaw, "weekly")
        r.frequency = .daily
        XCTAssertEqual(r.frequencyRaw, "daily")
        XCTAssertEqual(r.frequency, .daily)
    }

    func testScheduleText() {
        let daily = RecurringRule(amount: 1, isExpense: true, category: nil, ledger: nil, frequency: .daily)
        XCTAssertEqual(daily.scheduleText, "每天")

        let weekly = RecurringRule(amount: 1, isExpense: true, category: nil, ledger: nil, frequency: .weekly, anchorDay: 4)
        XCTAssertEqual(weekly.scheduleText, "每周三")   // weekday 4 = Wed (1=Sun)

        let monthly = RecurringRule(amount: 1, isExpense: true, category: nil, ledger: nil, frequency: .monthly, anchorDay: 15)
        XCTAssertEqual(monthly.scheduleText, "每月 15 日")
    }

    func testFrequencyLabels() {
        XCTAssertEqual(RecurringFrequency.daily.label, "每天")
        XCTAssertEqual(RecurringFrequency.weekly.label, "每周")
        XCTAssertEqual(RecurringFrequency.monthly.label, "每月")
        XCTAssertEqual(RecurringFrequency.allCases.count, 3)
    }

    // MARK: Calendar helper

    func testStartOfMonth() {
        let cal = Calendar.current
        let mid = TestSupport.date(2026, 7, 15)
        let start = cal.startOfMonth(for: mid)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 1)
    }

    // MARK: TransactionSearch edge

    func testTotalsEmpty() {
        let totals = TransactionSearch.totals([])
        XCTAssertEqual(totals.expense, 0)
        XCTAssertEqual(totals.income, 0)
    }

    // MARK: SyncStatus default

    func testSyncStatusDefault() {
        // Not asserting a fixed value (a prior CloudKit-configured run may flip it); just that
        // the flag is readable/settable without crashing.
        let prev = SyncStatus.iCloudActive
        SyncStatus.iCloudActive = true
        XCTAssertTrue(SyncStatus.iCloudActive)
        SyncStatus.iCloudActive = prev
    }
}

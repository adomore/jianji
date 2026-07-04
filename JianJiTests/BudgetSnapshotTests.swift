import XCTest
@testable import JianJi

/// Coverage for BudgetSnapshot (widget bridge data) + budget-alert threshold logic.
final class BudgetSnapshotTests: XCTestCase {

    func testComputedFields() {
        let s = BudgetSnapshot(monthLabel: "2026年7月", ledgerName: "默认",
                               expense: 2400, income: 8000, budget: 3000, updatedAt: Date())
        XCTAssertEqual(s.remaining, 600)
        XCTAssertFalse(s.overBudget)
        XCTAssertEqual(s.ratio, 0.8, accuracy: 0.0001)
    }

    func testOverBudget() {
        let s = BudgetSnapshot(monthLabel: "m", ledgerName: "l",
                               expense: 3500, income: 0, budget: 3000, updatedAt: Date())
        XCTAssertTrue(s.overBudget)
        XCTAssertEqual(s.remaining, -500)
        XCTAssertEqual(s.ratio, 1.0)          // clamped
    }

    func testNoBudgetRatioZero() {
        let s = BudgetSnapshot(monthLabel: "m", ledgerName: "l",
                               expense: 500, income: 0, budget: 0, updatedAt: Date())
        XCTAssertEqual(s.ratio, 0)
        XCTAssertFalse(s.overBudget)
    }

    func testCodableRoundTripAndLoad() throws {
        let s = BudgetSnapshot(monthLabel: "2026年7月", ledgerName: "旅行",
                               expense: 120.5, income: 0, budget: 1000, updatedAt: Date())
        let data = try JSONEncoder().encode(s)
        // Write into the shared suite and read it back through load().
        let d = UserDefaults(suiteName: BudgetSnapshot.appGroup)
        d?.set(data, forKey: BudgetSnapshot.key)
        let loaded = BudgetSnapshot.load()
        XCTAssertEqual(loaded?.ledgerName, "旅行")
        XCTAssertEqual(loaded?.expense, 120.5)
        d?.removeObject(forKey: BudgetSnapshot.key)
    }

    // MARK: budget alert thresholds (pure)

    func testAlertThresholds() {
        XCTAssertNil(NotificationManager.alert(forRatio: 0.0))
        XCTAssertNil(NotificationManager.alert(forRatio: 0.79))
        XCTAssertEqual(NotificationManager.alert(forRatio: 0.8), .warn)
        XCTAssertEqual(NotificationManager.alert(forRatio: 0.99), .warn)
        XCTAssertEqual(NotificationManager.alert(forRatio: 1.0), .over)
        XCTAssertEqual(NotificationManager.alert(forRatio: 1.5), .over)
    }
}

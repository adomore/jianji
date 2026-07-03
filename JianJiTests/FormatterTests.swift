import XCTest
@testable import JianJi

/// Functional coverage of money/date formatting (PRD §9.3 — always from Decimal).
final class FormatterTests: XCTestCase {

    func testAmountGrouping() {
        XCTAssertEqual(Fmt.amount(Decimal(string: "1234.5")!), "1,234.50")
        XCTAssertEqual(Fmt.amount(0), "0.00")
        XCTAssertEqual(Fmt.amount(Decimal(string: "999999.99")!), "999,999.99")
    }

    func testMoney() {
        XCTAssertEqual(Fmt.money(25), "¥25.00")
        XCTAssertEqual(Fmt.money(Decimal(string: "8000")!), "¥8,000.00")
    }

    func testSigned() {
        XCTAssertEqual(Fmt.signed(25, isExpense: true), "-25.00")
        XCTAssertEqual(Fmt.signed(8000, isExpense: false), "+8,000.00")
    }

    func testDayMonth() {
        XCTAssertEqual(Fmt.dayMonth(TestSupport.date(2000, 1, 1)), "1月1日")
        XCTAssertEqual(Fmt.dayMonth(TestSupport.date(2026, 7, 4)), "7月4日")
    }

    func testYearMonth() {
        XCTAssertEqual(Fmt.yearMonth(TestSupport.date(2026, 7, 4)), "2026年7月")
    }

    func testWeekdayShort() {
        // 2000-01-01 was a Saturday; 2000-01-02 a Sunday. Guards the wd-1 indexing.
        XCTAssertEqual(Fmt.weekdayShort(TestSupport.date(2000, 1, 1)), "周六")
        XCTAssertEqual(Fmt.weekdayShort(TestSupport.date(2000, 1, 2)), "周日")
    }

    /// Precision guard — the whole reason the app uses Decimal not Double (PRD §9.3).
    func testDecimalPrecision() {
        let sum = Decimal(string: "0.1")! + Decimal(string: "0.2")!
        XCTAssertEqual(Fmt.amount(sum), "0.30")
    }
}

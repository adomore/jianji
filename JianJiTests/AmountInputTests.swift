import XCTest
@testable import JianJi

/// Functional coverage of the keypad amount buffer (PRD §4.1 金额规则).
final class AmountInputTests: XCTestCase {

    func testEmptyState() {
        let a = AmountInput()
        XCTAssertEqual(a.display, "0.00")
        XCTAssertTrue(a.isEmpty)
        XCTAssertFalse(a.isValid)          // 0 cannot be saved
        XCTAssertEqual(a.decimalValue, 0)
    }

    func testBasicDigits() {
        var a = AmountInput()
        a.tap("1"); a.tap("2")
        XCTAssertEqual(a.display, "12")
        XCTAssertEqual(a.decimalValue, 12)
        XCTAssertTrue(a.isValid)
    }

    func testLeadingZeroIsReplaced() {
        var a = AmountInput()
        a.tap("0")
        XCTAssertEqual(a.display, "0")
        a.tap("5")
        XCTAssertEqual(a.display, "5")     // "05" is not allowed
    }

    func testDecimalPoint() {
        var a = AmountInput()
        a.tap(".")
        XCTAssertEqual(a.display, "0.")     // leading "." becomes "0."
        a.tap("5")
        XCTAssertEqual(a.display, "0.5")
        XCTAssertEqual(a.decimalValue, Decimal(string: "0.5"))
    }

    func testDoubleDecimalIgnored() {
        var a = AmountInput()
        a.tap("1"); a.tap("."); a.tap(".")
        XCTAssertEqual(a.display, "1.")     // second "." is a no-op
    }

    func testMaxTwoDecimals() {
        var a = AmountInput()
        for c in ["1", ".", "2", "3", "4"] { a.tap(c) }
        XCTAssertEqual(a.display, "1.23")   // third decimal rejected
    }

    func testIntegerMaxSixDigitsThenOverflow() {
        var a = AmountInput()
        for c in ["1", "2", "3", "4", "5", "6"] { a.tap(c) }
        XCTAssertEqual(a.display, "123456")
        a.tap("7")
        XCTAssertEqual(a.display, "123456") // 7th integer digit rejected
        XCTAssertTrue(a.overflow)
    }

    func testMaxValueBoundary() {
        var a = AmountInput()
        for c in ["9", "9", "9", "9", "9", "9", ".", "9", "9"] { a.tap(c) }
        XCTAssertEqual(a.display, "999999.99")   // PRD max
        XCTAssertEqual(a.decimalValue, Decimal(string: "999999.99"))
    }

    func testBackspaceClearsToEmpty() {
        var a = AmountInput()
        a.tap("1"); a.tap("2"); a.tap("⌫")
        XCTAssertEqual(a.display, "1")
        a.tap("⌫")
        XCTAssertTrue(a.isEmpty)
        XCTAssertEqual(a.display, "0.00")
    }

    func testSetNormalizesTrailingZeros() {
        var a = AmountInput()
        a.set(25)
        XCTAssertEqual(a.text, "25")             // ".00" stripped
        a.set(Decimal(string: "25.5")!)
        XCTAssertEqual(a.text, "25.50")          // non-zero decimals kept
        XCTAssertEqual(a.decimalValue, Decimal(string: "25.5"))
    }

    func testClear() {
        var a = AmountInput()
        a.tap("9"); a.tap("9"); a.tap("9"); a.tap("9"); a.tap("9"); a.tap("9"); a.tap("7")
        XCTAssertTrue(a.overflow)
        a.clear()
        XCTAssertTrue(a.isEmpty)
        XCTAssertFalse(a.overflow)
    }
}

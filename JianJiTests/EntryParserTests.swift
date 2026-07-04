import XCTest
@testable import JianJi

/// Functional coverage of the voice/OCR keyword parser (PRD §4.3).
@MainActor
final class EntryParserTests: XCTestCase {

    // MARK: amount

    func testParseAmountPlain() {
        XCTAssertEqual(EntryParser.parseAmount("午饭花了25"), 25)
    }

    func testParseAmountDecimal() {
        XCTAssertEqual(EntryParser.parseAmount("买奶茶18.5"), Decimal(string: "18.5"))
    }

    func testParseAmountKuaiJiao() {
        XCTAssertEqual(EntryParser.parseAmount("23块5"), Decimal(string: "23.5"))
    }

    func testParseAmountKuaiOnly() {
        XCTAssertEqual(EntryParser.parseAmount("打车花了23块"), 23)
    }

    func testParseAmountNone() {
        XCTAssertNil(EntryParser.parseAmount("今天天气不错"))
    }

    // MARK: date

    func testParseDateToday() {
        XCTAssertTrue(Calendar.current.isDateInToday(EntryParser.parseDate("买菜")))
    }

    func testParseDateYesterday() {
        XCTAssertTrue(Calendar.current.isDateInYesterday(EntryParser.parseDate("昨天打车")))
    }

    func testParseDateBeforeYesterday() {
        let d = EntryParser.parseDate("前天吃饭")
        let expected = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        XCTAssertTrue(Calendar.current.isDate(d, inSameDayAs: expected))
    }

    // MARK: note

    func testParseNoteUsesFirstKeyword() {
        // PRD example: 昨天打车花了23块 → 备注：打车
        XCTAssertEqual(EntryParser.parseNote("昨天打车花了23块", categoryName: "交通"), "打车")
    }

    // MARK: full parse (needs categories)

    @MainActor
    func testFullParseLunch() throws {              // PRD §4.3 acceptance #1
        let cats = try TestSupport.categories(TestSupport.makeSeededContainer())
        let d = EntryParser.parse("午饭花了25", isExpense: true, categories: cats, source: .voice)
        XCTAssertEqual(d.amount, 25)
        XCTAssertEqual(d.categoryName, "餐饮")
        XCTAssertTrue(Calendar.current.isDateInToday(d.date))
        XCTAssertEqual(d.source, .voice)
    }

    @MainActor
    func testFullParseTaxiYesterday() throws {
        let cats = try TestSupport.categories(TestSupport.makeSeededContainer())
        let d = EntryParser.parse("昨天打车花了23块", isExpense: true, categories: cats, source: .voice)
        XCTAssertEqual(d.amount, 23)
        XCTAssertEqual(d.categoryName, "交通")
        XCTAssertEqual(d.note, "打车")
        XCTAssertTrue(Calendar.current.isDateInYesterday(d.date))
    }

    @MainActor
    func testFullParseUnrelatedFallsBack() throws { // PRD §4.3 acceptance #2 (失败兜底)
        let cats = try TestSupport.categories(TestSupport.makeSeededContainer())
        let d = EntryParser.parse("今天天气不错", isExpense: true, categories: cats, source: .voice)
        XCTAssertNil(d.amount)                       // amount empty → manual entry
        XCTAssertEqual(d.categoryName, "其他")
    }

    @MainActor
    func testIncomeSalary() throws {
        let cats = try TestSupport.categories(TestSupport.makeSeededContainer())
        let d = EntryParser.parse("发工资了8000", isExpense: false, categories: cats, source: .voice)
        XCTAssertEqual(d.amount, 8000)
        XCTAssertEqual(d.categoryName, "工资")
    }

    /// The exact phrase the user reported: "午餐支出25元" → 餐饮 / 支出 / 25.
    @MainActor
    func testFullParseLunchExpensePhrase() throws {
        let cats = try TestSupport.categories(TestSupport.makeSeededContainer())
        // default segment is 收入 here, but "支出" in the phrase must win → expense
        let d = EntryParser.parse("午餐支出25元", isExpense: false, categories: cats, source: .voice)
        XCTAssertEqual(d.amount, 25)
        XCTAssertEqual(d.categoryName, "餐饮")
        XCTAssertTrue(d.isExpense)
    }

    func testDetectIsExpense() {
        XCTAssertTrue(EntryParser.detectIsExpense("午餐支出25", default: false))   // 支出 → expense
        XCTAssertTrue(EntryParser.detectIsExpense("买菜30", default: false))       // 买 → expense
        XCTAssertFalse(EntryParser.detectIsExpense("工资8000", default: true))     // 工资 → income
        XCTAssertFalse(EntryParser.detectIsExpense("收到红包200", default: true))  // 收到/红包 → income
        XCTAssertTrue(EntryParser.detectIsExpense("吃饭", default: true))          // no hint → fall back
    }
}

import XCTest
import SwiftData
@testable import JianJi

/// Coverage for ActiveLedger.resolve fallback chain (stored → default → first).
@MainActor
final class ActiveLedgerTests: XCTestCase {

    private func makeLedgers() -> [Ledger] {
        let a = Ledger(name: "默认", symbolName: "books.vertical.fill", colorHex: "FF9500", isDefault: true, sortOrder: 0)
        let b = Ledger(name: "旅行", symbolName: "airplane", colorHex: "007AFF", isDefault: false, sortOrder: 1)
        return [a, b]
    }

    func testResolvesStoredID() {
        let ls = makeLedgers()
        let travel = ls[1]
        XCTAssertEqual(ActiveLedger.resolve(ls, activeID: travel.id.uuidString)?.id, travel.id)
    }

    func testFallsBackToDefaultWhenIDMissing() {
        let ls = makeLedgers()
        let r = ActiveLedger.resolve(ls, activeID: "nonexistent-id")
        XCTAssertEqual(r?.name, "默认")
        XCTAssertTrue(r?.isDefault ?? false)
    }

    func testFallsBackToFirstWhenNoDefault() {
        let a = Ledger(name: "甲", symbolName: "wallet.pass.fill", colorHex: "FF9500", isDefault: false, sortOrder: 0)
        let b = Ledger(name: "乙", symbolName: "cart.fill", colorHex: "007AFF", isDefault: false, sortOrder: 1)
        let r = ActiveLedger.resolve([a, b], activeID: "")
        XCTAssertEqual(r?.name, "甲")
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(ActiveLedger.resolve([], activeID: "anything"))
    }

    func testStorageKeyStable() {
        XCTAssertEqual(ActiveLedger.storageKey, "activeLedgerID")
    }
}

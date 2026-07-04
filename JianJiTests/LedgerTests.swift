import XCTest
import SwiftData
@testable import JianJi

/// Coverage for multi-ledger: seeding/migration, active-ledger resolution,
/// per-ledger filtering, and the delete-reassigns-to-default rule.
@MainActor
final class LedgerTests: XCTestCase {

    func testDefaultLedgerSeeded() throws {
        let ledgers = try TestSupport.ledgers(TestSupport.makeSeededContainer())
        XCTAssertEqual(ledgers.count, 1)
        XCTAssertTrue(ledgers[0].isDefault)
        XCTAssertEqual(ledgers[0].name, "默认账本")
    }

    func testSeedIsIdempotent() throws {
        let c = try TestSupport.makeSeededContainer()
        SeedData.seedLedgerIfNeeded(c.mainContext)          // second call
        XCTAssertEqual(try TestSupport.ledgers(c).count, 1)  // no duplicate default
    }

    func testOrphanBillsMigratedToDefault() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        let tx = Transaction(amount: 25, isExpense: true, category: food)  // no ledger (legacy)
        ctx.insert(tx)
        try ctx.save()
        XCTAssertNil(tx.ledger)

        SeedData.seedLedgerIfNeeded(ctx)                     // migrate
        XCTAssertTrue(tx.ledger?.isDefault ?? false)
    }

    func testResolveActiveLedger() throws {
        let c = try TestSupport.makeSeededContainer()
        let def = try TestSupport.ledgers(c)[0]
        let other = Ledger(name: "旅行", sortOrder: 1)
        c.mainContext.insert(other)
        try c.mainContext.save()
        let ledgers = try TestSupport.ledgers(c)

        XCTAssertEqual(ActiveLedger.resolve(ledgers, activeID: other.id.uuidString)?.id, other.id)
        XCTAssertEqual(ActiveLedger.resolve(ledgers, activeID: "unknown")?.id, def.id)  // fallback → default
        XCTAssertEqual(ActiveLedger.resolve(ledgers, activeID: "")?.id, def.id)         // empty → default
    }

    func testPerLedgerFiltering() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let def = try TestSupport.ledgers(c)[0]
        let travel = Ledger(name: "旅行", sortOrder: 1); ctx.insert(travel)
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        ctx.insert(Transaction(amount: 25, isExpense: true, category: food, ledger: def))
        ctx.insert(Transaction(amount: 300, isExpense: true, category: food, ledger: travel))
        ctx.insert(Transaction(amount: 200, isExpense: true, category: food, ledger: travel))
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(all.filter { $0.ledger?.id == def.id }.count, 1)
        let travelTx = all.filter { $0.ledger?.id == travel.id }
        XCTAssertEqual(travelTx.count, 2)
        XCTAssertEqual(travelTx.reduce(Decimal(0)) { $0 + $1.amount }, 500)
    }

    /// Deleting a book must move its bills to the default book, never delete them.
    func testDeleteLedgerReassignsBills() throws {
        let c = try TestSupport.makeSeededContainer()
        let ctx = c.mainContext
        let def = try TestSupport.ledgers(c)[0]
        let travel = Ledger(name: "旅行", sortOrder: 1); ctx.insert(travel)
        let food = try TestSupport.categories(c).first { $0.name == "餐饮" }!
        let tx = Transaction(amount: 300, isExpense: true, category: food, ledger: travel)
        ctx.insert(tx)
        try ctx.save()

        // mirror LedgerView.delete: reassign to default, then remove the book
        for t in try ctx.fetch(FetchDescriptor<Transaction>()) where t.ledger?.id == travel.id {
            t.ledger = def
        }
        ctx.delete(travel)
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 1)  // bill kept
        XCTAssertEqual(tx.ledger?.id, def.id)                                   // moved to default
        XCTAssertEqual(try TestSupport.ledgers(c).count, 1)                     // travel removed
    }
}

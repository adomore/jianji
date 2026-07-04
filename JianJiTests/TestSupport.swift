import Foundation
import SwiftData
@testable import JianJi

/// Shared helpers for the test target.
enum TestSupport {

    /// A fresh in-memory store seeded with the 12 built-in categories + default 账本.
    @MainActor
    static func makeSeededContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, JianJi.Category.self, Ledger.self,
                                           configurations: config)
        SeedData.seedIfNeeded(container.mainContext)
        SeedData.seedLedgerIfNeeded(container.mainContext)
        return container
    }

    @MainActor
    static func categories(_ container: ModelContainer) throws -> [JianJi.Category] {
        try container.mainContext.fetch(
            FetchDescriptor<JianJi.Category>(sortBy: [SortDescriptor(\.sortOrder)])
        )
    }

    @MainActor
    static func ledgers(_ container: ModelContainer) throws -> [Ledger] {
        try container.mainContext.fetch(
            FetchDescriptor<Ledger>(sortBy: [SortDescriptor(\.sortOrder)])
        )
    }

    /// Deterministic date at local noon (noon avoids DST/timezone day-boundary flakiness).
    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }
}

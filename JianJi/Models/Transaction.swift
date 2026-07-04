import Foundation
import SwiftData

/// How a transaction was entered. PRD §6.2 — `source` enum.
enum EntrySource: String {
    case manual
    case voice
    case image
}

/// A single bill / transaction. PRD §6.2 / §6.3.
///
/// `amount` is always a positive `Decimal` — the sign is derived from `isExpense`.
/// Decimal (never Double) is a hard requirement from PRD §9.3 to avoid money-rounding bugs.
@Model
final class Transaction {
    var id: UUID = UUID()
    var amount: Decimal = 0          // always positive; use Decimal, never Double
    var isExpense: Bool = true
    var category: Category?
    var ledger: Ledger?              // which 账本 this bill belongs to
    var date: Date = Date()          // when the spend happened (user-editable)
    var note: String = ""
    var source: String = EntrySource.manual.rawValue   // manual / voice / image
    var rawText: String?             // voice transcript or OCR full text, for debugging
    var createdAt: Date = Date()

    init(amount: Decimal,
         isExpense: Bool,
         category: Category?,
         date: Date = .now,
         note: String = "",
         source: EntrySource = .manual,
         rawText: String? = nil,
         ledger: Ledger? = nil) {
        self.amount = amount
        self.isExpense = isExpense
        self.category = category
        self.ledger = ledger
        self.date = date
        self.note = note
        self.source = source.rawValue
        self.rawText = rawText
        self.createdAt = .now
    }

    /// Signed amount for arithmetic where sign matters.
    var signedAmount: Decimal { isExpense ? -amount : amount }
}

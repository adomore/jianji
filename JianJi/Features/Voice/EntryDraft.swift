import Foundation

/// A not-yet-saved transaction produced by voice or OCR, shown in the confirm card.
/// `amount == nil` means parsing failed to find a number — the card then focuses the
/// amount field so the user falls straight through to manual entry (PRD §4.3 失败兜底).
struct EntryDraft {
    var isExpense: Bool
    var amount: Decimal?
    var categoryName: String
    var date: Date
    var note: String
    var rawText: String
    var source: EntrySource

    func resolvedCategory(in categories: [Category]) -> Category? {
        categories.first { $0.isExpense == isExpense && $0.name == categoryName }
            ?? categories.first { $0.isExpense == isExpense && $0.name == "其他" }
    }
}

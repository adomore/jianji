import SwiftUI
import SwiftData

/// A spending / income category. PRD §6.2.
///
/// Note on icons: the PRD suggests SF Symbols, and we keep `symbolName` for that.
/// The approved visual prototype, however, uses emoji glyphs, so `emoji` is the
/// primary on-screen icon and is what the pixel-perfect UI renders. Both are stored
/// so a future settings screen can switch to SF Symbols without a data migration.
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "📦"
    var symbolName: String = "shippingbox.fill"
    /// Base color hex (no leading #). The soft "tint" fill used behind the icon is
    /// this color at `tintOpacity`.
    var colorHex: String = "787880"
    var tintOpacity: Double = 0.16
    var isExpense: Bool = true
    var sortOrder: Int = 0
    var isBuiltin: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    init(name: String,
         emoji: String,
         symbolName: String,
         colorHex: String,
         tintOpacity: Double,
         isExpense: Bool,
         sortOrder: Int,
         isBuiltin: Bool) {
        self.name = name
        self.emoji = emoji
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.tintOpacity = tintOpacity
        self.isExpense = isExpense
        self.sortOrder = sortOrder
        self.isBuiltin = isBuiltin
    }

    /// Base (solid) color.
    var color: Color { Color(hex: colorHex) }

    /// Soft background fill behind the icon — matches the prototype's per-category rgba tints.
    var tint: Color { Color(hex: colorHex).opacity(tintOpacity) }
}

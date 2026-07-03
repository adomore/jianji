import Foundation

/// Amount entry buffer, ported from the prototype's `tap()` logic (`AddSheet.dc.html`).
/// Rules (PRD §4.1): ≤ 2 decimals, integer part ≤ 6 digits (max 999999.99), no leading
/// zeros, no double decimal point, cannot be 0 to save.
struct AmountInput {
    private(set) var text: String = ""
    private(set) var overflow = false   // set true when a keypress was rejected for exceeding max

    /// "0.00" placeholder when empty, otherwise the raw typed string.
    var display: String { text.isEmpty ? "0.00" : text }
    var isEmpty: Bool { text.isEmpty }

    var decimalValue: Decimal { Decimal(string: text) ?? 0 }
    var isValid: Bool { decimalValue > 0 }

    mutating func tap(_ ch: String) {
        overflow = false
        switch ch {
        case "⌫":
            if !text.isEmpty { text.removeLast() }
        case ".":
            if text.contains(".") { return }
            text = (text.isEmpty ? "0" : text) + "."
        default:
            if let dotIndex = text.firstIndex(of: ".") {
                let decimals = text.distance(from: text.index(after: dotIndex), to: text.endIndex)
                if decimals >= 2 { return }
                text += ch
            } else if text == "0" {
                text = ch
            } else if text.count >= 6 {
                overflow = true
                return
            } else {
                text += ch
            }
        }
    }

    mutating func clear() { text = ""; overflow = false }

    mutating func set(_ value: Decimal) {
        // Normalize to at most 2 decimals as a typed string.
        text = Fmt.amount(value).replacingOccurrences(of: ",", with: "")
        if text.hasSuffix(".00") { text = String(text.dropLast(3)) }
    }
}

import Foundation

/// Amount entry buffer, ported from the prototype's `tap()` logic (`AddSheet.dc.html`).
/// Rules (PRD §4.1): ≤ 2 decimals, integer part ≤ 6 digits (max 999999.99), no leading
/// zeros, no double decimal point, cannot be 0 to save.
///
/// Supports an insertion cursor so a mistyped digit in the middle can be fixed by tapping
/// to position the caret, then inserting / deleting there — instead of only deleting from
/// the end. When the cursor sits at the end (the default), behaviour is identical to a
/// plain append-only keypad.
struct AmountInput {
    private(set) var text: String = ""
    private(set) var cursor: Int = 0   // insertion index into `text`, 0...text.count
    private(set) var overflow = false  // set true when a keypress was rejected for exceeding max

    /// "0.00" placeholder when empty, otherwise the raw typed string.
    var display: String { text.isEmpty ? "0.00" : text }
    var isEmpty: Bool { text.isEmpty }

    var decimalValue: Decimal { Decimal(string: text) ?? 0 }
    var isValid: Bool { decimalValue > 0 }

    mutating func tap(_ ch: String) {
        overflow = false
        switch ch {
        case "⌫":
            guard cursor > 0 else { return }
            let idx = text.index(text.startIndex, offsetBy: cursor - 1)
            text.remove(at: idx)
            cursor -= 1
        case ".":
            guard !text.contains(".") else { return }
            insert(cursor == 0 ? "0." : ".")   // leading dot becomes "0."
        default:
            guard canInsertDigit() else { overflow = true; return }
            insert(ch)
        }
        normalizeLeadingZero()
    }

    /// Move the caret (called when tapping a digit in the amount display). Clamped.
    mutating func setCursor(_ i: Int) {
        cursor = min(max(0, i), text.count)
    }

    mutating func clear() { text = ""; cursor = 0; overflow = false }

    mutating func set(_ value: Decimal) {
        // Normalize to at most 2 decimals as a typed string.
        text = Fmt.amount(value).replacingOccurrences(of: ",", with: "")
        if text.hasSuffix(".00") { text = String(text.dropLast(3)) }
        cursor = text.count
    }

    // MARK: helpers

    private mutating func insert(_ s: String) {
        let idx = text.index(text.startIndex, offsetBy: cursor)
        text.insert(contentsOf: s, at: idx)
        cursor += s.count
    }

    /// Whether one more digit fits, respecting where the caret is (integer vs decimal part).
    private func canInsertDigit() -> Bool {
        guard let dot = text.firstIndex(of: ".") else {
            return text.count < 6           // no decimals yet → integer part cap
        }
        let dotPos = text.distance(from: text.startIndex, to: dot)
        if cursor > dotPos {                // caret is in the decimal part
            let decimals = text.distance(from: text.index(after: dot), to: text.endIndex)
            return decimals < 2
        } else {                            // caret is in the integer part
            return dotPos < 6
        }
    }

    /// Drop any leading zero once a real digit follows it (keeps "0." intact).
    private mutating func normalizeLeadingZero() {
        while text.count >= 2 {
            let chars = Array(text)
            guard chars[0] == "0", chars[1] != "." else { break }
            text.removeFirst()
            if cursor > 0 { cursor -= 1 }
        }
    }
}

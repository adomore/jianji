import SwiftUI

// MARK: - Color(hex:)

extension Color {
    /// Create a Color from a hex string. Accepts "#RRGGBB", "RRGGBB", or "RRGGBBAA".
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xff) / 255
            g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255
            a = Double(v & 0xff) / 255
        } else {
            r = Double((v >> 16) & 0xff) / 255
            g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Theme

/// Design tokens ported 1:1 from the Claude Design prototype (`HomeScreen.dc.html` /
/// `AddSheet.dc.html`). The exact same hex / rgba values are reproduced here so the
/// SwiftUI build matches the approved mockups pixel-for-pixel in both light and dark.
struct Theme {
    let dark: Bool

    init(_ scheme: ColorScheme) { dark = scheme == .dark }
    init(dark: Bool) { self.dark = dark }

    // Brand — orange main color; income always green.
    var accent: Color { dark ? Color(hex: "FF9F0A") : Color(hex: "FF9500") }
    var green:  Color { dark ? Color(hex: "30D158") : Color(hex: "34C759") }
    var red:    Color { dark ? Color(hex: "FF453A") : Color(hex: "FF3B30") }

    // Surfaces
    var card:    Color { dark ? Color(hex: "1C1C1E") : Color(hex: "FFFFFF") }
    var groupBg: Color { dark ? Color(hex: "000000") : Color(hex: "F2F2F7") }
    var bar:     Color { dark ? Color(hex: "121214").opacity(0.82) : Color(hex: "F9F9F9").opacity(0.85) }

    // Text
    var text: Color { dark ? Color(hex: "FFFFFF") : Color(hex: "000000") }
    var sec:  Color { (dark ? Color(hex: "EBEBF5") : Color(hex: "3C3C43")).opacity(0.6) }
    var ter:  Color { (dark ? Color(hex: "EBEBF5") : Color(hex: "3C3C43")).opacity(0.3) }

    // Fills / separators
    var sep:  Color { dark ? Color(hex: "545458").opacity(0.65) : Color(hex: "3C3C43").opacity(0.12) }
    var fill: Color { Color(hex: "787880").opacity(dark ? 0.22 : 0.12) }

    // Home indicator handle
    var indicator: Color { dark ? Color.white.opacity(0.6) : Color.black.opacity(0.28) }
}

// MARK: - Environment access

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(dark: false)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

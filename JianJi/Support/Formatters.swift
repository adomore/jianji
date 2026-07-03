import Foundation
import UIKit

/// Currency & date formatting. Money is always formatted from `Decimal` (PRD §9.3).
enum Fmt {

    /// "1,234.50" — thousands separators, exactly 2 decimals, no symbol.
    static func amount(_ value: Decimal) -> String {
        amountFormatter.string(from: value as NSDecimalNumber) ?? "0.00"
    }

    /// "¥1,234.50"
    static func money(_ value: Decimal) -> String { "¥" + amount(value) }

    /// Signed money for a transaction row: "-25.00" / "+8,000.00".
    static func signed(_ value: Decimal, isExpense: Bool) -> String {
        (isExpense ? "-" : "+") + amount(value)
    }

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.decimalSeparator = "."      // pin both separators so CNY renders 1,234.50 on any device locale
        f.usesGroupingSeparator = true
        return f
    }()

    private static var zhCN: Locale { Locale(identifier: "zh_CN") }

    /// "7月4日"
    static func dayMonth(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = zhCN; f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    /// "周六"
    static func weekdayShort(_ date: Date) -> String {
        let wd = Calendar.current.component(.weekday, from: date) // 1 = Sunday
        return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][wd - 1]
    }

    /// "2026年7月"
    static func yearMonth(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = zhCN; f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }
}

/// Light haptic on save (PRD §5.2.5).
enum Haptics {
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

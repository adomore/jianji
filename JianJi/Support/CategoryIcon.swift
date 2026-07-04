import SwiftUI

/// Category icon chip — white SF Symbol on a solid-color circle (随手记 style),
/// used everywhere a category is shown so the look stays unified.
struct CategoryIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

extension Category {
    /// Convenience: the icon chip for this category at a given size.
    func icon(size: CGFloat = 38) -> CategoryIcon {
        CategoryIcon(symbol: symbolName, color: color, size: size)
    }
}

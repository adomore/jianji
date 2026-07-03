import SwiftUI

/// Plain button with a subtle press-down scale + dim, matching the prototype's
/// `style-active="transform:scale(0.97)"` feedback on the keypad, category chips and
/// entry buttons. Keeps the label's own colors (no system tint), like `.plain`.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dim: Double = 0.05

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -dim : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

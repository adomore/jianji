import SwiftUI

/// Screen 5 — home empty state. PRD §4.2 (空状态) / §5.2.4.
struct EmptyStateView: View {
    @Environment(\.theme) private var t
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(t.accent.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "yensign")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(t.accent)
            }

            VStack(spacing: 6) {
                Text("还没有账单")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(t.text)
                Text("记下第一笔，开始掌握你的钱去哪了")
                    .font(.system(size: 14)).foregroundStyle(t.sec)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                Text("记下第一笔账")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 13)
                    .background(t.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 40)
    }
}

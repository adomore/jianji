import SwiftUI

/// The orange monthly summary card at the top of the home screen. PRD §4.2.
struct MonthSummaryCard: View {
    @Environment(\.theme) private var t
    let month: Date
    let expense: Decimal
    let income: Decimal
    var onPrev: () -> Void
    var onNext: () -> Void

    private var balance: Decimal { income - expense }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                chevron("chevron.left", "上个月", action: onPrev)
                Text(Fmt.yearMonth(month))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                chevron("chevron.right", "下个月", action: onNext)
            }

            Text("本月支出")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 14)

            Text(Fmt.money(expense))
                .font(.system(size: 36, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 32) {
                stat("本月收入", Fmt.money(income), negative: false)
                stat("结余", Fmt.money(balance), negative: balance < 0)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func chevron(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func stat(_ label: String, _ value: String, negative: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
            if negative {
                // 白字 + 红胶囊：负结余在橙底上最醒目。
                Text(value)
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color(hex: "FF3B30"), in: Capsule())
            } else {
                Text(value)
                    .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }
}

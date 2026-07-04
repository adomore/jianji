import SwiftUI

/// The orange monthly summary card at the top of the home screen. PRD §4.2.
/// Three equal columns (支出 / 收入 / 结余) under a centered month switcher — 随手记 style.
struct MonthSummaryCard: View {
    @Environment(\.theme) private var t
    let month: Date
    let expense: Decimal
    let income: Decimal
    var onPrev: () -> Void
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                chevron("chevron.left", "上个月", action: onPrev)
                Text(Fmt.yearMonth(month))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                chevron("chevron.right", "下个月", action: onNext)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                column("支出", Fmt.money(expense))
                divider
                column("收入", Fmt.money(income))
                divider
                column("结余", Fmt.money(income - expense))
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
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

    /// One of the three equal-width stat columns: big number on top, label below.
    private func column(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.22)).frame(width: 0.5, height: 32)
    }
}

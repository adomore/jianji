import SwiftUI

/// The orange monthly summary card at the top of the home screen. PRD §4.2.
struct MonthSummaryCard: View {
    @Environment(\.theme) private var t
    let month: Date
    let expense: Decimal
    let income: Decimal
    var budget: Decimal = 0            // 0 = 不限
    var onPrev: () -> Void
    var onNext: () -> Void
    var onTapMonth: () -> Void = {}    // tap the title to jump to any month

    private var balance: Decimal { income - expense }
    private var overBudget: Bool { budget > 0 && expense > budget }
    private var budgetRatio: Double {
        guard budget > 0 else { return 0 }
        return min(1, max(0, ((expense / budget) as NSDecimalNumber).doubleValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                chevron("chevron.left", "上个月", action: onPrev)
                Button(action: onTapMonth) {
                    HStack(spacing: 5) {
                        Text(Fmt.yearMonth(month))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择月份")
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

            if budget > 0 { budgetBar.padding(.top, 14) }
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

    private var budgetBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25)).frame(height: 6)
                    Capsule().fill(overBudget ? Color(hex: "FF3B30") : .white)
                        .frame(width: geo.size.width * budgetRatio, height: 6)
                }
            }
            .frame(height: 6)
            HStack {
                Text("预算 " + Fmt.money(budget))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                if overBudget {
                    Text("超 " + Fmt.money(expense - budget))
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color(hex: "FF3B30"), in: Capsule())
                } else {
                    Text("剩 " + Fmt.money(budget - expense))
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}

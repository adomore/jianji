import SwiftUI

/// One day's section: header (date · weekday · today badge · totals) + a card of rows.
struct DaySection: View {
    @Environment(\.theme) private var t
    let group: DayGroup
    var onTapRow: (Transaction) -> Void
    var onDelete: (Transaction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(Fmt.dayMonth(group.day))
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(t.text)
                    Text(Fmt.weekdayShort(group.day))
                        .font(.system(size: 13)).foregroundStyle(t.sec)
                    if group.isToday {
                        Text("今天")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(t.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(t.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                Spacer()
                Text(totalsText)
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(t.sec)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // Rows card
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, tx in
                    TransactionRow(tx: tx, showSeparator: idx < group.items.count - 1)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapRow(tx) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { onDelete(tx) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .background(t.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private var totalsText: String {
        var parts: [String] = []
        if group.income > 0 { parts.append("收入 " + Fmt.money(group.income)) }
        if group.expense > 0 { parts.append("支出 " + Fmt.money(group.expense)) }
        return parts.joined(separator: " · ")
    }
}

/// A single transaction row: icon chip, name, note, signed amount.
struct TransactionRow: View {
    @Environment(\.theme) private var t
    let tx: Transaction
    var showSeparator: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(tx.category?.emoji ?? "📦")
                .font(.system(size: 19))
                .frame(width: 38, height: 38)
                .background(tx.category?.tint ?? t.fill, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(tx.category?.name ?? "其他")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(t.text)
                if !tx.note.isEmpty {
                    Text(tx.note)
                        .font(.system(size: 12)).foregroundStyle(t.sec).lineLimit(1)
                }
            }
            Spacer(minLength: 8)

            Text(Fmt.signed(tx.amount, isExpense: tx.isExpense))
                .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                .foregroundStyle(tx.isExpense ? t.text : t.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottomLeading) {
            if showSeparator {
                Rectangle().fill(t.sep).frame(height: 0.5).padding(.leading, 64)
            }
        }
    }
}

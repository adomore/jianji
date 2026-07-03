import SwiftUI
import SwiftData

/// Screen 1 (明细首页) + Screen 5 (空状态). PRD §4.2 / §4.4-list.
struct HomeView: View {
    var onAdd: () -> Void

    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var all: [Transaction]

    /// First day of the currently displayed month.
    @State private var month: Date = Calendar.current.startOfMonth(for: .now)
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?

    private var cal: Calendar { Calendar.current }

    private var monthTx: [Transaction] {
        all.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    private var monthExpense: Decimal { monthTx.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var monthIncome: Decimal { monthTx.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }

    /// Transactions grouped by day, days sorted newest-first.
    private var days: [DayGroup] {
        let grouped = Dictionary(grouping: monthTx) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            DayGroup(day: day, items: grouped[day]!.sorted { $0.createdAt > $1.createdAt })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    MonthSummaryCard(
                        month: month, expense: monthExpense, income: monthIncome,
                        onPrev: { shift(-1) }, onNext: { shift(1) }
                    )
                    .padding(.horizontal, 16)

                    if monthTx.isEmpty {
                        EmptyStateView(onAdd: onAdd)
                            .padding(.top, 80)
                    } else {
                        ForEach(days) { group in
                            DaySection(group: group, onTapRow: { editing = $0 }, onDelete: { pendingDelete = $0 })
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 120)           // clear the floating tab bar
                .animation(.easeInOut(duration: 0.25), value: all.count)  // new rows fade in (PRD §5.2.5)
            }
            .background(t.groupBg.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("明细")             // system large title → consistent with 设置
            .navigationBarTitleDisplayMode(.large)
            // Swipe left-right to change month (kept simultaneous so vertical scroll still works).
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { v in
                        guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                        if v.translation.width < -50 { shift(1) }
                        else if v.translation.width > 50 { shift(-1) }
                    }
            )
            .sheet(item: $editing) { tx in
                TransactionDetailView(transaction: tx)
                    .environment(\.theme, t)
            }
            .confirmationDialog("删除这笔账单？", isPresented: deleteBinding, titleVisibility: .visible) {
                Button("删除", role: .destructive) { performDelete() }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("删除后无法恢复。")
            }
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func shift(_ n: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            month = cal.date(byAdding: .month, value: n, to: month) ?? month
        }
        Haptics.tap()
    }

    private func performDelete() {
        guard let tx = pendingDelete else { return }
        context.delete(tx)
        try? context.save()
        pendingDelete = nil
        Haptics.tap()
    }
}

// MARK: - Day grouping

struct DayGroup: Identifiable {
    let day: Date
    let items: [Transaction]
    var id: Date { day }

    var expense: Decimal { items.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    var income: Decimal { items.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    var isToday: Bool { Calendar.current.isDateInToday(day) }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

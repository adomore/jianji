import SwiftUI
import SwiftData

/// Screen 1 (明细首页) + Screen 5 (空状态). PRD §4.2 / §4.4-list.
struct HomeView: View {
    var onAdd: () -> Void

    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var all: [Transaction]
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]
    @AppStorage(ActiveLedger.storageKey) private var activeLedgerID = ""
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @EnvironmentObject private var privacy: PrivacyGate
    @EnvironmentObject private var ledgerLock: LedgerLock

    /// First day of the currently displayed month.
    @State private var month: Date = Calendar.current.startOfMonth(for: .now)
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?
    @State private var showMonthPicker = false

    private var cal: Calendar { Calendar.current }
    private var activeLedger: Ledger? { ActiveLedger.resolve(ledgers, activeID: activeLedgerID) }
    /// Only the active book's bills feed the list & summary; private bills stay out until revealed.
    private var ledgerTx: [Transaction] {
        all.filter { $0.ledger?.id == activeLedger?.id && (privacy.revealed || !$0.isPrivate) }
    }
    /// True when the active book has private bills currently hidden.
    private var hasHiddenPrivate: Bool {
        !privacy.revealed && all.contains { $0.ledger?.id == activeLedger?.id && $0.isPrivate }
    }

    private var monthTx: [Transaction] {
        ledgerTx.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    private var monthExpense: Decimal { monthTx.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var monthIncome: Decimal { monthTx.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    /// Budget only applies to the current month (past months don't show a cap).
    private var displayBudget: Decimal {
        cal.isDate(month, equalTo: .now, toGranularity: .month) ? Decimal(monthlyBudget) : 0
    }

    @ViewBuilder private var privacyButton: some View {
        if privacy.revealed {
            Button { privacy.hide() } label: { Image(systemName: "eye.slash") }
                .accessibilityLabel("隐藏隐私账单")
        } else if hasHiddenPrivate {
            Button { privacy.reveal() } label: { Image(systemName: "lock.fill") }
                .accessibilityLabel("显示隐私账单")
        }
    }

    /// Transactions grouped by day, days sorted newest-first.
    private var days: [DayGroup] {
        let grouped = Dictionary(grouping: monthTx) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            DayGroup(day: day, items: grouped[day]!.sorted { $0.createdAt > $1.createdAt })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if ledgerLock.isOpen(activeLedger) {
                    homeScroll
                } else if let l = activeLedger {
                    LedgerUnlockView(ledger: l)   // active book is a locked private 账本
                }
            }
            .navigationTitle("明细")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if ledgerLock.isOpen(activeLedger) {
                        NavigationLink { SearchView() } label: { Image(systemName: "magnifyingglass") }
                            .accessibilityLabel("搜索账单")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if ledgerLock.isOpen(activeLedger) { privacyButton }
                }
            }
        }
    }

    private var homeScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                MonthSummaryCard(
                    month: month, expense: monthExpense, income: monthIncome,
                    budget: displayBudget,
                    onPrev: { shift(-1) }, onNext: { shift(1) },
                    onTapMonth: { showMonthPicker = true }
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
            .animation(.easeInOut(duration: 0.25), value: ledgerTx.count)  // new rows fade in (PRD §5.2.5)
        }
        .background(t.groupBg.ignoresSafeArea())
        .scrollIndicators(.hidden)
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
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerView(month: $month).environment(\.theme, t)
        }
        .confirmationDialog("删除这笔账单？", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("删除", role: .destructive) { performDelete() }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("删除后无法恢复。")
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

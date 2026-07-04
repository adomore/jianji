import SwiftUI
import SwiftData

/// 账本 tab — the active book's overview + the full book list (tap to switch,
/// swipe to edit/delete, + to create). Deleting a book moves its bills to 默认账本.
struct LedgerView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]
    @Query private var all: [Transaction]
    @AppStorage(ActiveLedger.storageKey) private var activeID = ""
    @EnvironmentObject private var privacy: PrivacyGate

    @State private var showAdd = false
    @State private var editing: Ledger?
    @State private var pendingDelete: Ledger?

    private var t: Theme { Theme(scheme) }
    private var active: Ledger? { ActiveLedger.resolve(ledgers, activeID: activeID) }

    var body: some View {
        NavigationStack {
            List {
                if let a = active {
                    Section("当前账本") { overview(a) }
                }
                Section("全部账本") {
                    ForEach(ledgers) { l in
                        NavigationLink { LedgerReportView(ledger: l).environment(\.theme, t) } label: { row(l) }
                            .swipeActions(edge: .leading) {
                                if l.id != active?.id {
                                    Button { switchTo(l) } label: { Label("设为当前", systemImage: "checkmark.circle") }
                                        .tint(t.accent)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if !l.isDefault {
                                    Button(role: .destructive) { pendingDelete = l } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                Button { editing = l } label: { Label("编辑", systemImage: "pencil") }
                                    .tint(t.accent)
                            }
                    }
                    .onMove(perform: move)
                }
            }
            .navigationTitle("账本")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新建账本")
                }
            }
            .safeAreaPadding(.bottom, 90)
            .sheet(isPresented: $showAdd) { LedgerEditView(ledger: nil).environment(\.theme, t) }
            .sheet(item: $editing) { l in LedgerEditView(ledger: l).environment(\.theme, t) }
            .confirmationDialog("删除该账本？", isPresented: deleteBinding, titleVisibility: .visible) {
                Button("删除", role: .destructive) { if let l = pendingDelete { delete(l) } }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("账本删除后，其账单会移入「默认账本」，不会被删除。")
            }
        }
    }

    // MARK: rows

    private func overview(_ l: Ledger) -> some View {
        let s = stats(l)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CategoryIcon(symbol: l.symbolName, color: l.color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(t.text)
                    Text("\(s.count) 笔记录").font(.system(size: 13)).foregroundStyle(t.sec)
                }
            }
            HStack(spacing: 0) {
                col("结余", Fmt.money(s.income - s.expense), (s.income - s.expense) >= 0 ? t.text : t.red)
                col("收入", Fmt.money(s.income), t.green)
                col("支出", Fmt.money(s.expense), t.text)
            }
        }
        .padding(.vertical, 6)
    }

    private func col(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 12)).foregroundStyle(t.sec)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ l: Ledger) -> some View {
        let s = stats(l)
        return HStack(spacing: 12) {
            CategoryIcon(symbol: l.symbolName, color: l.color, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.name).font(.system(size: 16)).foregroundStyle(t.text)
                Text("\(s.count) 笔 · 结余 \(Fmt.money(s.income - s.expense))")
                    .font(.system(size: 12)).foregroundStyle(t.sec)
            }
            Spacer()
            if l.id == active?.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(t.accent)
            }
        }
        .contentShape(Rectangle())
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: actions

    private func stats(_ l: Ledger) -> (count: Int, income: Decimal, expense: Decimal) {
        let tx = all.filter { $0.ledger?.id == l.id && (privacy.revealed || !$0.isPrivate) }
        let income = tx.filter { !$0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        let expense = tx.filter { $0.isExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        return (tx.count, income, expense)
    }

    private func switchTo(_ l: Ledger) {
        activeID = l.id.uuidString
        Haptics.tap()
    }

    private func move(from source: IndexSet, to dest: Int) {
        var arr = ledgers
        arr.move(fromOffsets: source, toOffset: dest)
        for (i, l) in arr.enumerated() { l.sortOrder = i }
        try? context.save()
    }

    private func delete(_ l: Ledger) {
        guard !l.isDefault else { return }
        let fallback = ledgers.first { $0.isDefault } ?? ledgers.first { $0.id != l.id }
        guard let def = fallback else { return }
        // Move this book's bills to the default book (never delete bills), then remove the book.
        for tx in all where tx.ledger?.id == l.id { tx.ledger = def }
        if activeID == l.id.uuidString { activeID = def.id.uuidString }
        context.delete(l)
        try? context.save()
        pendingDelete = nil
        Haptics.tap()
    }
}

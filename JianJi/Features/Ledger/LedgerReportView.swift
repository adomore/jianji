import SwiftUI
import SwiftData

/// Per-ledger 月度报表 — pushed from the 账本 list. Scoped to ONE book (independent of
/// the globally-active book). Reuses the month card + day sections; adds a 图表 breakdown.
struct LedgerReportView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query private var all: [Transaction]
    @AppStorage(ActiveLedger.storageKey) private var activeID = ""
    @EnvironmentObject private var privacy: PrivacyGate

    let ledger: Ledger

    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var mode = 0                       // 0 明细, 1 图表
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?

    private var t: Theme { Theme(scheme) }
    private var cal: Calendar { Calendar.current }

    private var monthTx: [Transaction] {
        all.filter { $0.ledger?.id == ledger.id
                     && (privacy.revealed || !$0.isPrivate)
                     && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }
    private var expense: Decimal { monthTx.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var income: Decimal { monthTx.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }

    private var days: [DayGroup] {
        let g = Dictionary(grouping: monthTx) { cal.startOfDay(for: $0.date) }
        return g.keys.sorted(by: >).map { DayGroup(day: $0, items: g[$0]!.sorted { $0.createdAt > $1.createdAt }) }
    }

    private struct Slice { let name: String; let amount: Decimal; let color: Color; let symbol: String }
    private var slices: [Slice] {
        let groups = Dictionary(grouping: monthTx.filter { $0.isExpense }) { $0.category?.name ?? "其他" }
        return groups.map { name, txs in
            Slice(name: name,
                  amount: txs.reduce(Decimal(0)) { $0 + $1.amount },
                  color: txs.first?.category?.color ?? Color(hex: "787880"),
                  symbol: txs.first?.category?.symbolName ?? "shippingbox.fill")
        }.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MonthSummaryCard(month: month, expense: expense, income: income,
                                 onPrev: { shift(-1) }, onNext: { shift(1) })
                    .padding(.horizontal, 16).padding(.top, 4)

                Picker("", selection: $mode) {
                    Text("明细").tag(0); Text("图表").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 2)

                if mode == 0 {
                    if monthTx.isEmpty { emptyHint } else { detailList }
                } else {
                    chart
                }
            }
            .padding(.bottom, 120)
        }
        .background(t.groupBg.ignoresSafeArea())
        .environment(\.theme, t)
        .scrollIndicators(.hidden)
        .navigationTitle(ledger.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if activeID == ledger.id.uuidString {
                    Text("当前账本").font(.system(size: 13)).foregroundStyle(t.sec)
                } else {
                    Button("设为当前") { activeID = ledger.id.uuidString; Haptics.tap() }
                }
            }
        }
        .sheet(item: $editing) { tx in TransactionDetailView(transaction: tx).environment(\.theme, t) }
        .confirmationDialog("删除这笔账单？", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("删除", role: .destructive) { performDelete() }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private var detailList: some View {
        ForEach(days) { g in
            DaySection(group: g, onTapRow: { editing = $0 }, onDelete: { pendingDelete = $0 })
        }
        .padding(.top, 6)
    }

    @ViewBuilder private var chart: some View {
        if slices.isEmpty {
            emptyHint
        } else {
            VStack(spacing: 0) {
                ForEach(Array(slices.enumerated()), id: \.offset) { i, s in
                    rankingRow(s, last: i == slices.count - 1)
                }
            }
            .background(t.card, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16).padding(.top, 12)
        }
    }

    private func rankingRow(_ s: Slice, last: Bool) -> some View {
        let top = slices.first?.amount ?? 1
        let ratio: CGFloat = top > 0 ? CGFloat(((s.amount / top) as NSDecimalNumber).doubleValue) : 0
        return HStack(spacing: 12) {
            CategoryIcon(symbol: s.symbol, color: s.color, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(s.name).font(.system(size: 15, weight: .medium)).foregroundStyle(t.text)
                    Spacer()
                    Text(Fmt.money(s.amount)).font(.system(size: 15, weight: .semibold))
                        .monospacedDigit().foregroundStyle(t.text)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(t.fill).frame(height: 5)
                        Capsule().fill(s.color).frame(width: geo.size.width * ratio, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .bottomLeading) {
            if !last { Rectangle().fill(t.sep).frame(height: 0.5).padding(.leading, 60) }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.system(size: 30)).foregroundStyle(t.ter)
            Text("本月暂无记录").font(.system(size: 14)).foregroundStyle(t.sec)
        }
        .frame(maxWidth: .infinity).padding(.top, 70)
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
        if let tx = pendingDelete { context.delete(tx); try? context.save() }
        pendingDelete = nil
    }
}

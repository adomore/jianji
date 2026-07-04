import SwiftUI
import SwiftData
import Charts

/// Screen 4 — 图表. PRD §4.5. Month switch, three totals, category donut + ranking,
/// daily-spend bar chart. Uses Apple's Swift Charts (SectorMark / BarMark), no 3rd party.
struct ChartsView: View {
    @Environment(\.theme) private var t
    @Query(sort: \Transaction.date, order: .reverse) private var all: [Transaction]
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]
    @AppStorage(ActiveLedger.storageKey) private var activeLedgerID = ""
    @EnvironmentObject private var privacy: PrivacyGate
    @EnvironmentObject private var ledgerLock: LedgerLock

    @State private var month: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedCategory: String?
    @State private var selectedAngle: Double?

    private var cal: Calendar { Calendar.current }
    private var activeLedger: Ledger? { ActiveLedger.resolve(ledgers, activeID: activeLedgerID) }
    private var monthTx: [Transaction] {
        all.filter { $0.ledger?.id == activeLedger?.id
                     && (privacy.revealed || !$0.isPrivate)
                     && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }
    private var expense: Decimal { monthTx.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var income: Decimal { monthTx.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }

    private var slices: [CategorySlice] {
        let groups = Dictionary(grouping: monthTx.filter { $0.isExpense }) { $0.category?.name ?? "其他" }
        return groups.map { name, txs in
            CategorySlice(
                name: name,
                amount: txs.reduce(0) { $0 + $1.amount },
                emoji: txs.first?.category?.emoji ?? "📦",
                symbolName: txs.first?.category?.symbolName ?? "shippingbox.fill",
                color: txs.first?.category?.color ?? Color(hex: "787880")
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var dailyBars: [DailyBar] {
        let range = cal.range(of: .day, in: .month, for: month) ?? 1..<2
        let byDay = Dictionary(grouping: monthTx.filter { $0.isExpense }) { cal.component(.day, from: $0.date) }
        return range.map { day in
            let amt = byDay[day]?.reduce(Decimal(0)) { $0 + $1.amount } ?? 0
            return DailyBar(day: day, amount: amt)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if ledgerLock.isOpen(activeLedger) { chartsScroll }
                else if let l = activeLedger { LedgerUnlockView(ledger: l) }
            }
            .navigationTitle("图表")             // system large title → consistent with 明细 / 设置
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var chartsScroll: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthSwitcher
                totalsRow
                donutCard
                if !slices.isEmpty { rankingCard }
                dailyCard
            }
            .padding(.top, 4)
            .padding(.bottom, 120)           // clear the floating tab bar
        }
        .background(t.groupBg.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }

    private var monthSwitcher: some View {
        HStack(spacing: 20) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("上个月")
            Text(Fmt.yearMonth(month)).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.text)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("下个月")
        }
        .foregroundStyle(t.accent)
        .padding(.horizontal, 16)
    }

    private var totalsRow: some View {
        HStack(spacing: 10) {
            totalCell("支出", expense, t.text)
            totalCell("收入", income, t.green)
            totalCell("结余", income - expense, income - expense >= 0 ? t.green : t.red)
        }
        .padding(.horizontal, 16)
    }

    private func totalCell(_ label: String, _ value: Decimal, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(t.sec)
            Text(Fmt.money(value)).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(t.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出分类占比").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.text)

            if slices.isEmpty {
                emptyHint("本月还没有支出")
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("金额", slice.amountDouble),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.color)
                    .opacity(selectedCategory == nil || selectedCategory == slice.name ? 1 : 0.35)
                }
                .frame(height: 200)
                // Tap a sector to highlight it and show its amount in the center (PRD §4.5).
                .chartAngleSelection(value: $selectedAngle)
                .onChange(of: selectedAngle) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = newValue.flatMap { sliceName(atAngleValue: $0) }
                    }
                }
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        if let sel = selectedCategory, let s = slices.first(where: { $0.name == sel }) {
                            CategoryIcon(symbol: s.symbolName, color: s.color, size: 34)
                            Text(s.name).font(.system(size: 13)).foregroundStyle(t.sec)
                            Text(Fmt.money(s.amount)).font(.system(size: 16, weight: .semibold))
                                .monospacedDigit().foregroundStyle(t.text)
                        } else {
                            Text("本月支出").font(.system(size: 12)).foregroundStyle(t.sec)
                            Text(Fmt.money(expense)).font(.system(size: 18, weight: .bold))
                                .monospacedDigit().foregroundStyle(t.text)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var rankingCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                Button {
                    withAnimation { selectedCategory = selectedCategory == slice.name ? nil : slice.name }
                } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(symbol: slice.symbolName, color: slice.color, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(slice.name).font(.system(size: 15, weight: .medium)).foregroundStyle(t.text)
                                Spacer()
                                Text(Fmt.money(slice.amount)).font(.system(size: 15, weight: .semibold))
                                    .monospacedDigit().foregroundStyle(t.text)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(t.fill).frame(height: 5)
                                    Capsule().fill(slice.color)
                                        .frame(width: geo.size.width * ratio(slice), height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .overlay(alignment: .bottomLeading) {
                        if idx < slices.count - 1 {
                            Rectangle().fill(t.sep).frame(height: 0.5).padding(.leading, 62)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(t.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日支出").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.text)
            if expense == 0 {
                emptyHint("本月还没有支出")
            } else {
                Chart(dailyBars) { bar in
                    BarMark(
                        x: .value("日", bar.day),
                        y: .value("支出", bar.amountDouble),
                        width: .fixed(6)
                    )
                    .cornerRadius(3)
                    .foregroundStyle(t.accent)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: [1, 10, 20, maxDay]) { v in
                        AxisValueLabel { if let d = v.as(Int.self) { Text("\(d)日") } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(t.sec)
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var maxDay: Int { (cal.range(of: .day, in: .month, for: month)?.upperBound ?? 29) - 1 }

    private func ratio(_ slice: CategorySlice) -> CGFloat {
        guard let top = slices.first?.amount, top > 0 else { return 0 }
        let fraction = (slice.amount / top) as NSDecimalNumber
        return CGFloat(fraction.doubleValue)
    }

    /// SectorMark angle selection reports a value in the cumulative amount domain;
    /// walk the slices to find which one the tap landed in.
    private func sliceName(atAngleValue value: Double) -> String? {
        var acc = 0.0
        for s in slices {
            acc += s.amountDouble
            if value <= acc { return s.name }
        }
        return slices.last?.name
    }

    private func shift(_ n: Int) {
        withAnimation { month = cal.date(byAdding: .month, value: n, to: month) ?? month }
        selectedCategory = nil
        Haptics.tap()
    }
}

// MARK: - Chart data

struct CategorySlice: Identifiable {
    let name: String
    let amount: Decimal
    let emoji: String
    let symbolName: String
    let color: Color
    var id: String { name }
    var amountDouble: Double { Double(truncating: amount as NSDecimalNumber) }
}

struct DailyBar: Identifiable {
    let day: Int
    let amount: Decimal
    var id: Int { day }
    var amountDouble: Double { Double(truncating: amount as NSDecimalNumber) }
}

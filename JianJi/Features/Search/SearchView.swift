import SwiftUI
import SwiftData

/// 账单搜索与筛选 — search the active book's bills by note / category / amount, filter by
/// income-vs-expense. Privacy-aware (hidden private bills stay out until revealed elsewhere).
struct SearchView: View {
    @Environment(\.theme) private var t
    @Query(sort: \Transaction.date, order: .reverse) private var all: [Transaction]
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]
    @AppStorage(ActiveLedger.storageKey) private var activeLedgerID = ""
    @EnvironmentObject private var privacy: PrivacyGate

    @State private var query = ""
    @State private var kind: TransactionSearch.Kind = .all
    @State private var editing: Transaction?

    private var activeLedger: Ledger? { ActiveLedger.resolve(ledgers, activeID: activeLedgerID) }

    private var scoped: [Transaction] {
        all.filter { $0.ledger?.id == activeLedger?.id && (privacy.revealed || !$0.isPrivate) }
    }
    private var results: [Transaction] {
        TransactionSearch.filter(scoped, query: query, kind: kind)
    }
    private var totals: (expense: Decimal, income: Decimal) { TransactionSearch.totals(results) }

    var body: some View {
        List {
            Section {
                Picker("类型", selection: $kind) {
                    Text("全部").tag(TransactionSearch.Kind.all)
                    Text("支出").tag(TransactionSearch.Kind.expense)
                    Text("收入").tag(TransactionSearch.Kind.income)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            if !results.isEmpty {
                Section {
                    HStack {
                        Text("\(results.count) 笔").foregroundStyle(t.sec)
                        Spacer()
                        if totals.expense > 0 {
                            Text("支出 " + Fmt.money(totals.expense)).foregroundStyle(t.red)
                        }
                        if totals.income > 0 {
                            Text("收入 " + Fmt.money(totals.income)).foregroundStyle(t.green)
                        }
                    }
                    .font(.system(size: 12)).monospacedDigit()
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                if results.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "输入关键词搜索账单" : "没有匹配的账单",
                        systemImage: "magnifyingglass",
                        description: Text(query.isEmpty ? "可搜备注、分类或金额" : "换个关键词或筛选条件试试"))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(results) { tx in
                        Button { editing = tx } label: {
                            TransactionRow(tx: tx, showSeparator: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜备注、分类、金额")
        .navigationTitle("搜索账单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { tx in
            TransactionDetailView(transaction: tx).environment(\.theme, t)
        }
    }
}

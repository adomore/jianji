import SwiftUI
import SwiftData

/// 月度预算：set a monthly spending cap. Compared against the active book's current-month
/// expense (same number shown on the home card). 0 = 不限.
struct BudgetView: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("monthlyBudget") private var budget: Double = 0
    @AppStorage(ActiveLedger.storageKey) private var activeID = ""
    @Query private var all: [Transaction]
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]

    @State private var text = ""
    @FocusState private var focused: Bool

    private var t: Theme { Theme(scheme) }
    private var cal: Calendar { Calendar.current }

    private var monthExpense: Decimal {
        let active = ActiveLedger.resolve(ledgers, activeID: activeID)
        return all.filter {
            $0.isExpense && $0.ledger?.id == active?.id
            && cal.isDate($0.date, equalTo: .now, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    private var budgetDec: Decimal { Decimal(budget) }
    private var remaining: Decimal { budgetDec - monthExpense }
    private var ratio: Double {
        guard budget > 0 else { return 0 }
        return min(1, max(0, ((monthExpense / budgetDec) as NSDecimalNumber).doubleValue))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Text("¥").foregroundStyle(t.sec)
                    TextField("不限", text: $text)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                        .onChange(of: text) { _, v in budget = Double(v) ?? 0 }
                }
            } header: { Text("本月预算") } footer: {
                Text("设置每月支出上限，超支会在首页月度卡片红色提醒。留空或 0 表示不限。")
            }

            if budget > 0 {
                Section {
                    line("本月已支出", Fmt.money(monthExpense), t.text)
                    line(remaining >= 0 ? "剩余可用" : "已超支",
                         Fmt.money(abs(remaining)),
                         remaining >= 0 ? t.green : t.red)
                    ProgressView(value: ratio)
                        .tint(remaining >= 0 ? t.accent : t.red)
                        .padding(.vertical, 4)
                }
                Section {
                    Button("清除预算", role: .destructive) { budget = 0; text = "" }
                }
            }
        }
        .navigationTitle("月度预算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack { Spacer(); Button("完成") { focused = false } }
            }
        }
        .onAppear { text = budget > 0 ? trimmed(budget) : "" }
    }

    private func line(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(t.text)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(color)
        }
    }

    private func trimmed(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}

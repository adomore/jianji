import SwiftUI
import SwiftData

/// 账本 tab — overview of the single "默认账本". Multi-ledger is out of first-version
/// scope (PRD §1.4), surfaced here as a "即将推出" affordance so the tab is honest.
struct LedgerView: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var all: [Transaction]
    private var t: Theme { Theme(scheme) }

    private var income: Decimal { all.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var expense: Decimal { all.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var balance: Decimal { income - expense }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    defaultBookCard
                    comingSoon
                }
                .padding(.top, 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .background(t.groupBg.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("账本")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var defaultBookCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(t.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("默认账本").font(.system(size: 17, weight: .semibold)).foregroundStyle(t.text)
                    Text("\(all.count) 笔记录").font(.system(size: 13)).foregroundStyle(t.sec)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("结余").font(.system(size: 13)).foregroundStyle(t.sec)
                Text(Fmt.money(balance))
                    .font(.system(size: 30, weight: .bold)).monospacedDigit()
                    .foregroundStyle(balance >= 0 ? t.text : t.red)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }

            HStack(spacing: 0) {
                totalCol("总收入", Fmt.money(income), t.green)
                Rectangle().fill(t.sep).frame(width: 0.5, height: 30)
                totalCol("总支出", Fmt.money(expense), t.text)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func totalCol(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 12)).foregroundStyle(t.sec)
        }
        .frame(maxWidth: .infinity)
    }

    private var comingSoon: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.rectangle.on.folder")
                .font(.system(size: 18)).foregroundStyle(t.sec).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("多账本").font(.system(size: 16)).foregroundStyle(t.text)
                Text("分账本记账即将推出").font(.system(size: 12)).foregroundStyle(t.sec)
            }
            Spacer()
            Text("即将推出").font(.system(size: 13)).foregroundStyle(t.ter)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(t.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

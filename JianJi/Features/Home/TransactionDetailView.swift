import SwiftUI
import SwiftData

/// Tap a row → edit any field, or delete. PRD §4.2 (点一行进入详情页，可修改任意字段).
struct TransactionDetailView: View {
    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @Bindable var transaction: Transaction

    @State private var amountText: String = ""
    @State private var showDelete = false

    private var cats: [Category] { categories.filter { $0.isExpense == transaction.isExpense } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: Binding(
                        get: { transaction.isExpense },
                        set: { newVal in
                            transaction.isExpense = newVal
                            // Keep category on the correct side.
                            if transaction.category?.isExpense != newVal {
                                transaction.category = cats.first
                            }
                        })) {
                        Text("支出").tag(true)
                        Text("收入").tag(false)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("金额")
                        Spacer()
                        Text("¥").foregroundStyle(t.sec)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 140)
                    }
                }

                Section("分类") {
                    Picker("分类", selection: Binding(
                        get: { transaction.category?.id },
                        set: { id in transaction.category = cats.first { $0.id == id } })) {
                        ForEach(cats) { c in
                            Text("\(c.emoji)  \(c.name)").tag(Optional(c.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    DatePicker("日期", selection: $transaction.date,
                               in: ...Date.now, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    HStack {
                        Text("备注")
                        TextField("添加备注…", text: $transaction.note)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button(role: .destructive) { showDelete = true } label: {
                        HStack { Spacer(); Text("删除账单"); Spacer() }
                    }
                }
            }
            .navigationTitle("账单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }
                }
            }
            .onAppear { amountText = Fmt.amount(transaction.amount) }
            // Other fields edit the object live; commit the staged amount on dismiss too,
            // so swiping the sheet away doesn't silently drop an amount edit.
            .onDisappear { applyAmount() }
            .confirmationDialog("删除这笔账单？", isPresented: $showDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    context.delete(transaction); try? context.save(); dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func applyAmount() {
        if let dec = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")), dec > 0 {
            transaction.amount = dec
        }
    }

    private func save() {
        applyAmount()
        try? context.save()
        Haptics.tap()
        dismiss()
    }
}

import SwiftUI
import SwiftData

/// Create or edit a 周期账单 (recurring bill template). `rule == nil` means create.
struct RecurringEditView: View {
    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]

    let rule: RecurringRule?

    @State private var isExpense: Bool
    @State private var amountText: String
    @State private var categoryID: UUID?
    @State private var ledgerID: UUID?
    @State private var note: String
    @State private var isPrivate: Bool
    @State private var frequency: RecurringFrequency
    @State private var anchorDay: Int
    @State private var startDate: Date

    init(rule: RecurringRule?) {
        self.rule = rule
        _isExpense  = State(initialValue: rule?.isExpense ?? true)
        _amountText = State(initialValue: rule.map { Fmt.plain($0.amount) } ?? "")
        _categoryID = State(initialValue: rule?.category?.id)
        _ledgerID   = State(initialValue: rule?.ledger?.id)
        _note       = State(initialValue: rule?.note ?? "")
        _isPrivate  = State(initialValue: rule?.isPrivate ?? false)
        _frequency  = State(initialValue: rule?.frequency ?? .monthly)
        _anchorDay  = State(initialValue: rule?.anchorDay ?? Calendar.current.component(.day, from: .now))
        _startDate  = State(initialValue: rule?.startDate ?? .now)
    }

    private var pickCats: [Category] { categories.filter { $0.isExpense == isExpense } }
    private var amount: Decimal { Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var canSave: Bool { amount > 0 && categoryID != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $isExpense) {
                        Text("支出").tag(true)
                        Text("收入").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isExpense) { _, _ in categoryID = pickCats.first?.id }

                    HStack {
                        Text("¥").foregroundStyle(t.sec)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 20, weight: .semibold)).monospacedDigit()
                    }
                }

                Section("分类") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(pickCats) { c in
                            VStack(spacing: 4) {
                                CategoryIcon(symbol: c.symbolName, color: c.color, size: 40)
                                    .overlay(Circle().stroke(t.accent, lineWidth: c.id == categoryID ? 3 : 0).padding(-3))
                                Text(c.name).font(.system(size: 11))
                                    .foregroundStyle(c.id == categoryID ? t.accent : t.sec)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { categoryID = c.id }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("周期") {
                    Picker("重复", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { f in Text(f.label).tag(f) }
                    }
                    if frequency == .weekly {
                        Picker("星期", selection: $anchorDay) {
                            let names = ["日", "一", "二", "三", "四", "五", "六"]
                            ForEach(1...7, id: \.self) { w in Text("周" + names[w - 1]).tag(w) }
                        }
                    } else if frequency == .monthly {
                        Picker("每月几号", selection: $anchorDay) {
                            ForEach(1...31, id: \.self) { d in Text("\(d) 日").tag(d) }
                        }
                    }
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }

                Section("其他") {
                    if ledgers.count > 1 {
                        Picker("记入账本", selection: $ledgerID) {
                            ForEach(ledgers) { l in Text(l.name).tag(Optional(l.id)) }
                        }
                    }
                    TextField("备注（可选）", text: $note)
                    Toggle("隐私记账", isOn: $isPrivate)
                }

                if frequency != .daily {
                    Section {
                        Text(previewText).font(.system(size: 13)).foregroundStyle(t.sec)
                    }
                }
            }
            .navigationTitle(rule == nil ? "新建周期账单" : "编辑周期账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(!canSave) }
            }
            .onAppear {
                if categoryID == nil { categoryID = pickCats.first?.id }
                if ledgerID == nil { ledgerID = (ledgers.first { $0.isDefault } ?? ledgers.first)?.id }
            }
        }
    }

    private var previewText: String {
        let sample = RecurringRule(amount: amount, isExpense: isExpense, category: nil, ledger: nil,
                                   frequency: frequency, anchorDay: anchorDay, startDate: startDate)
        return "将在「\(sample.scheduleText)」自动记一笔"
    }

    private func save() {
        guard canSave else { return }
        let cat = categories.first { $0.id == categoryID }
        let led = ledgers.first { $0.id == ledgerID } ?? ledgers.first { $0.isDefault } ?? ledgers.first
        let r: RecurringRule
        if let existing = rule {
            r = existing
            r.amount = amount; r.isExpense = isExpense; r.category = cat; r.ledger = led
            r.note = note.trimmingCharacters(in: .whitespaces); r.isPrivate = isPrivate
            r.frequency = frequency; r.anchorDay = anchorDay; r.startDate = startDate
        } else {
            r = RecurringRule(amount: amount, isExpense: isExpense, category: cat, ledger: led,
                              note: note.trimmingCharacters(in: .whitespaces), isPrivate: isPrivate,
                              frequency: frequency, anchorDay: anchorDay, startDate: startDate)
            context.insert(r)
        }
        try? context.save()
        // Post immediately if today already qualifies, so the first bill isn't a day late.
        RecurringEngine.materialize(context)
        Haptics.success()
        dismiss()
    }
}

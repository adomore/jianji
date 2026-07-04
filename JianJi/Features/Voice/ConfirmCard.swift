import SwiftUI

/// Screen 3 — the voice / image confirm card (确认卡片). PRD §4.3 / §5.3.
/// Dimmed backdrop + centered card; every field is editable; recognition never
/// auto-saves. When `amount` is nil the amount field auto-focuses (失败兜底 → 手动).
struct ConfirmCard: View {
    @Environment(\.theme) private var t

    let draft: EntryDraft
    let categories: [Category]
    var index: Int = 0
    var total: Int = 1
    var onCancel: () -> Void
    var onConfirm: (EntryDraft) -> Void

    @State private var isExpense: Bool
    @State private var amountText: String
    @State private var categoryName: String
    @State private var date: Date
    @State private var note: String
    @State private var showDate = false
    @FocusState private var amountFocused: Bool

    init(draft: EntryDraft, categories: [Category], index: Int = 0, total: Int = 1,
         onCancel: @escaping () -> Void, onConfirm: @escaping (EntryDraft) -> Void) {
        self.draft = draft
        self.categories = categories
        self.index = index
        self.total = total
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _isExpense = State(initialValue: draft.isExpense)
        _amountText = State(initialValue: draft.amount.map { Fmt.amount($0).replacingOccurrences(of: ",", with: "") } ?? "")
        _categoryName = State(initialValue: draft.categoryName)
        _date = State(initialValue: draft.date)
        _note = State(initialValue: draft.note)
    }

    private var sideCats: [Category] { categories.filter { $0.isExpense == isExpense } }
    private var currentCategory: Category? {
        sideCats.first { $0.name == categoryName } ?? sideCats.first { $0.name == "其他" }
    }
    private var amountValue: Decimal? {
        let d = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        return d > 0 ? d : nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                header

                if !draft.rawText.isEmpty {
                    rawRow
                }

                fieldRow(icon: "creditcard", label: "金额") { amountField }
                divider
                fieldRow(icon: "square.grid.2x2", label: "分类") { categoryMenu }
                divider
                fieldRow(icon: "calendar", label: "日期") {
                    Button { showDate = true } label: {
                        Text(Fmt.dayMonth(date)).font(.system(size: 16)).foregroundStyle(t.accent)
                    }.buttonStyle(.plain)
                }
                divider
                fieldRow(icon: "text.alignleft", label: "备注") {
                    TextField("添加备注…", text: $note)
                        .font(.system(size: 16)).multilineTextAlignment(.trailing).foregroundStyle(t.text)
                }

                buttons
            }
            .padding(.top, 20)
            .background(t.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.25), radius: 30, y: 8)
        }
        .sheet(isPresented: $showDate) {
            NavigationStack {
                DatePicker("日期", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .padding()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showDate = false } } }
            }
            .presentationDetents([.medium])
        }
        .onAppear { if draft.amount == nil { amountFocused = true } }
    }

    // MARK: rows

    private var header: some View {
        VStack(spacing: 4) {
            Text(draft.source == .voice ? "确认这笔账" : "确认识别结果")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(t.text)
            if total > 1 {
                Text("第 \(index + 1) / \(total) 张")
                    .font(.system(size: 12)).foregroundStyle(t.sec)
            }
        }
        .padding(.bottom, 14)
    }

    private var rawRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("识别原文").font(.system(size: 13)).foregroundStyle(t.sec)
            Text(draft.rawText)
                .font(.system(size: 13)).foregroundStyle(t.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
        .padding(12)
        .background(t.fill, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func fieldRow<Content: View>(icon: String, label: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(t.sec).frame(width: 22)
            Text(label).font(.system(size: 16)).foregroundStyle(t.text)
            Spacer(minLength: 12)
            content()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    private var amountField: some View {
        HStack(spacing: 2) {
            Text("¥").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.sec)
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 18, weight: .semibold)).monospacedDigit()
                .foregroundStyle(t.text)
                .multilineTextAlignment(.trailing)
                .focused($amountFocused)
                .frame(maxWidth: 130)
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("类型", selection: $isExpense) {
                Text("支出").tag(true); Text("收入").tag(false)
            }
            Divider()
            ForEach(sideCats) { c in
                Button { categoryName = c.name } label: { Label(c.name, systemImage: c.symbolName) }
            }
        } label: {
            HStack(spacing: 8) {
                if let c = currentCategory {
                    CategoryIcon(symbol: c.symbolName, color: c.color, size: 24)
                }
                Text(currentCategory?.name ?? "其他").font(.system(size: 16)).foregroundStyle(t.accent)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundStyle(t.sec)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(t.sep).frame(height: 0.5).padding(.leading, 20)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("取消")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(t.text)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(t.fill, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)

            Button {
                var result = draft
                result.isExpense = isExpense
                result.amount = amountValue
                // Use the resolved category (matches what's shown), so switching
                // 支出/收入 can never save a category name from the wrong side.
                result.categoryName = currentCategory?.name ?? "其他"
                result.date = date
                result.note = note.trimmingCharacters(in: .whitespaces)
                onConfirm(result)
            } label: {
                Text(index + 1 < total ? "确认并看下一张" : "确认记账")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(amountValue == nil ? t.accent.opacity(0.45) : t.accent,
                                in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(amountValue == nil)
        }
        .padding(20)
    }
}

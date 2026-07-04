import SwiftUI
import SwiftData
import UIKit

/// Screen 2 — the add-transaction sheet (记账弹出页). PRD §4.1 / §5.3.
/// Layout & pixel values ported from `AddSheet.dc.html`.
struct AddSheetView: View {
    var startInVoice: Bool = false

    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]
    @AppStorage(ActiveLedger.storageKey) private var activeLedgerID = ""

    private var activeLedger: Ledger? { ActiveLedger.resolve(ledgers, activeID: activeLedgerID) }

    @State private var isExpense = true
    @State private var selExpenseID: UUID?
    @State private var selIncomeID: UUID?
    @State private var amount = AmountInput()
    @State private var note = ""
    @State private var date = Date()
    @State private var isPrivate = false
    @State private var caretOn = true

    @State private var showDatePicker = false
    @State private var toast: String?

    // Voice / image confirm flow
    @StateObject private var speech = SpeechManager()
    @State private var draftQueue: [EntryDraft] = []
    @State private var draftTotal = 0
    @State private var showPhotos = false
    @State private var micDenied = false

    private var sideCats: [Category] { categories.filter { $0.isExpense == isExpense } }
    private var selectedCategory: Category? {
        let id = isExpense ? selExpenseID : selIncomeID
        return sideCats.first { $0.id == id } ?? sideCats.first
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            // Grid lives in a flexible scroll area: on the 390×844 reference it fills the
            // gap like a Spacer (identical look); on shorter screens it scrolls so the
            // amount + keypad below always stay fully visible.
            ScrollView { categoryGrid }
                .scrollIndicators(.hidden)
            amountRow
            noteAndDateRow
            entryButtons
            keypad
            Color.clear.frame(height: 20)
        }
        .background(t.card.ignoresSafeArea())
        .overlay { if speech.isRecording { RecordingOverlay(speech: speech).environment(\.theme, t) } }
        .overlay { if let d = draftQueue.first { confirmOverlay(d) } }
        .onAppear(perform: setup)
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .photosConfirm(isPresented: $showPhotos, isExpense: isExpense,
                       categories: categories) { draftQueue = $0; draftTotal = $0.count }
        .alert("需要麦克风权限", isPresented: $micDenied) {
            Button("去设置") { openSettings() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("「简记」需要麦克风和语音识别，把你说的话变成一笔账单。请在设置中开启。")
        }
    }

    // MARK: pieces

    private var grabber: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(t.ter).frame(width: 36, height: 5)
            .padding(.top, 8)
    }

    private var header: some View {
        ZStack {
            SegmentControl(isExpense: $isExpense).frame(width: 200)
            HStack {
                Button("取消") { dismiss() }
                    .font(.system(size: 17)).foregroundStyle(t.accent)
                Spacer()
                ledgerMenu          // 顶部快捷切换当前账本，新账单直接记入该账本
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var ledgerMenu: some View {
        Menu {
            ForEach(ledgers) { l in
                Button {
                    activeLedgerID = l.id.uuidString
                    Haptics.tap()
                } label: {
                    Label(l.name, systemImage: l.id == activeLedger?.id ? "checkmark" : l.symbolName)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: activeLedger?.symbolName ?? "books.vertical.fill")
                    .font(.system(size: 12))
                Text(activeLedger?.name ?? "账本")
                    .font(.system(size: 14, weight: .medium)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(t.accent)
            .frame(maxWidth: 130, alignment: .trailing)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                  spacing: 14) {
            ForEach(sideCats) { c in
                let selected = c.id == (isExpense ? selExpenseID : selIncomeID)
                Button {
                    if isExpense { selExpenseID = c.id } else { selIncomeID = c.id }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 6) {
                        CategoryIcon(symbol: c.symbolName, color: c.color, size: 52)
                            .overlay(
                                Circle().stroke(t.accent, lineWidth: selected ? 3 : 0)
                                    .padding(-3)
                            )
                        Text(c.name)
                            .font(.system(size: 12, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? t.accent : t.sec)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .frame(minHeight: 168, alignment: .top)
    }

    private var amountRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("¥").font(.system(size: 26, weight: .semibold)).foregroundStyle(t.sec)
            Text(amount.display)
                .font(.system(size: 46, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(amount.isEmpty ? t.ter : t.text)
            RoundedRectangle(cornerRadius: 2)
                .fill(t.accent).frame(width: 3, height: 38)
                .opacity(caretOn ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: caretOn)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .onAppear { caretOn.toggle() }
    }

    private var noteAndDateRow: some View {
        HStack(spacing: 10) {
            TextField("添加备注…", text: $note)
                .font(.system(size: 15)).foregroundStyle(t.text)
                .padding(.horizontal, 12).frame(height: 40)
                .background(t.fill, in: RoundedRectangle(cornerRadius: 10))

            Button { showDatePicker = true } label: {
                HStack(spacing: 6) {
                    Text(dateLabel).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.accent)
                    Text(Fmt.dayMonth(date)).font(.system(size: 13)).foregroundStyle(t.sec)
                }
                .padding(.horizontal, 14).frame(height: 40)
                .background(t.fill, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button { isPrivate.toggle(); Haptics.tap() } label: {
                Image(systemName: isPrivate ? "lock.fill" : "lock.open")
                    .font(.system(size: 16))
                    .foregroundStyle(isPrivate ? .white : t.sec)
                    .frame(width: 40, height: 40)
                    .background(isPrivate ? t.accent : t.fill, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPrivate ? "隐私记账已开" : "标记为隐私记账")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var dateLabel: String {
        Calendar.current.isDateInToday(date) ? "今天" : Fmt.weekdayShort(date)
    }

    private var entryButtons: some View {
        HStack(spacing: 10) {
            entryButton("🎤", "语音记账", action: startVoice)
            entryButton("🖼", "截图记账") { showPhotos = true }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "1E1E20").opacity(0.92), in: Capsule())
                    .offset(y: -46)
                    .transition(.opacity)
            }
        }
    }

    private func entryButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(icon).font(.system(size: 17))
                Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(t.text)
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(t.fill, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableStyle())
    }

    private var keypad: some View {
        // Four equal columns (3 digit columns + a tall 完成) so the pad fills the width
        // and 完成 matches the key width on any screen — no dead space on the sides.
        HStack(alignment: .top, spacing: 8) {
            keyColumn(["1", "4", "7", "."])
            keyColumn(["2", "5", "8", "0"])
            keyColumn(["3", "6", "9", "⌫"])
            Button(action: done) {
                Text("完成")
                    .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52 * 4 + 8 * 3)
                    .background(t.accent, in: RoundedRectangle(cornerRadius: 12))
                    .opacity(amount.isValid ? 1 : 0.45)
            }
            .buttonStyle(PressableStyle(scale: 0.98))
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private func keyColumn(_ keys: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(keys, id: \.self) { k in
                Button { press(k) } label: {
                    Text(k)
                        .font(.system(size: 25, weight: .medium)).foregroundStyle(t.text)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(t.fill, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(k == "⌫" ? "删除" : k)
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("日期", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding()
                .navigationTitle("选择日期").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showDatePicker = false } } }
        }
        .presentationDetents([.medium])
        .environment(\.theme, t)
    }

    // MARK: actions

    private func setup() {
        // Default selections → "其他".
        if selExpenseID == nil { selExpenseID = categories.first { $0.isExpense && $0.name == "其他" }?.id }
        if selIncomeID == nil { selIncomeID = categories.first { !$0.isExpense && $0.name == "其他" }?.id }
        if startInVoice { startVoice() }
    }

    private func press(_ k: String) {
        amount.tap(k)
        if amount.overflow { showToast("金额最大 999999.99") }
        Haptics.tap()
    }

    private func done() {
        guard amount.isValid else { showToast("请输入金额"); return }
        save(amount: amount.decimalValue, category: selectedCategory,
             date: date, note: note.trimmingCharacters(in: .whitespaces),
             isExpense: isExpense, source: .manual, rawText: nil)
    }

    private func save(amount: Decimal, category: Category?, date: Date, note: String,
                      isExpense: Bool, source: EntrySource, rawText: String?) {
        let tx = Transaction(amount: amount, isExpense: isExpense, category: category,
                             date: date, note: note, source: source, rawText: rawText,
                             ledger: activeLedger, isPrivate: isPrivate)
        context.insert(tx)
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { if toast == msg { toast = nil } }
        }
    }

    // MARK: voice

    private func startVoice() {
        speech.requestAndStart(
            onDenied: { micDenied = true },
            onFinished: { transcript in
                guard !transcript.isEmpty else { showToast("没听清，请再说一次"); return }
                let d = EntryParser.parse(transcript, isExpense: isExpense,
                                          categories: categories, source: .voice)
                draftQueue = [d]; draftTotal = 1
            })
    }

    @ViewBuilder
    private func confirmOverlay(_ d: EntryDraft) -> some View {
        ConfirmCard(
            draft: d,
            categories: categories,
            index: max(0, draftTotal - draftQueue.count),
            total: draftTotal,
            onCancel: { draftQueue = [] },
            onConfirm: { result in
                let tx = Transaction(amount: result.amount ?? 0, isExpense: result.isExpense,
                                     category: result.resolvedCategory(in: categories),
                                     date: result.date, note: result.note, source: result.source,
                                     rawText: result.rawText.isEmpty ? nil : result.rawText,
                                     ledger: activeLedger)
                context.insert(tx)
                try? context.save()
                Haptics.success()
                draftQueue.removeFirst()
                if draftQueue.isEmpty { dismiss() }   // last one saved → close the sheet
            }
        )
        // Force fresh @State when the queue advances to the next image.
        .id(draftQueue.count)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Segmented control (matches prototype's custom pill)

private struct SegmentControl: View {
    @Environment(\.theme) private var t
    @Binding var isExpense: Bool

    var body: some View {
        HStack(spacing: 0) {
            seg("支出", active: isExpense) { isExpense = true }
            seg("收入", active: !isExpense) { isExpense = false }
        }
        .padding(2)
        .background(t.fill, in: RoundedRectangle(cornerRadius: 9))
    }

    private func seg(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { action(); Haptics.tap() }) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? t.text : t.sec)
                .frame(maxWidth: .infinity).frame(height: 30)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(t.dark ? Color(hex: "636366") : .white)
                            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import SwiftData

/// Create or edit a 账本: name + icon + color. `ledger == nil` means create.
struct LedgerEditView: View {
    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ledger.sortOrder) private var ledgers: [Ledger]

    let ledger: Ledger?

    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String
    @State private var isPrivate: Bool
    @State private var password: String

    private let symbols = ["books.vertical.fill", "wallet.pass.fill", "creditcard.fill", "banknote.fill",
                           "house.fill", "cart.fill", "airplane", "gift.fill",
                           "heart.fill", "briefcase.fill", "graduationcap.fill", "pawprint.fill"]
    private let colors = ["FF9500", "007AFF", "34C759", "FF2D55", "AF52DE", "5856D6", "FF3B30", "00C7BE"]

    init(ledger: Ledger?) {
        self.ledger = ledger
        _name = State(initialValue: ledger?.name ?? "")
        _symbol = State(initialValue: ledger?.symbolName ?? "books.vertical.fill")
        _colorHex = State(initialValue: ledger?.colorHex ?? "FF9500")
        _isPrivate = State(initialValue: ledger?.isPrivate ?? false)
        _password = State(initialValue: "")
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isPrivate { return !password.isEmpty || ledger?.passwordHash != nil }   // needs a password
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        CategoryIcon(symbol: symbol, color: Color(hex: colorHex), size: 44)
                        TextField("账本名称", text: $name).font(.system(size: 17))
                    }
                }

                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(symbols, id: \.self) { s in
                            Image(systemName: s)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(s == symbol ? .white : t.sec)
                                .frame(width: 40, height: 40)
                                .background(s == symbol ? Color(hex: colorHex) : t.fill, in: Circle())
                                .contentShape(Circle())
                                .onTapGesture { symbol = s }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(t.text, lineWidth: hex == colorHex ? 2 : 0).padding(-3))
                                .contentShape(Circle())
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle(isOn: $isPrivate) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill").foregroundStyle(t.accent)
                            Text("隐私账本")
                        }
                    }
                    if isPrivate {
                        SecureField(ledger?.passwordHash != nil ? "设置新密码（留空则不修改）" : "设置账本密码",
                                    text: $password)
                            .textContentType(.newPassword)
                    }
                } header: { Text("隐私") } footer: {
                    Text("开启后，打开此账本需 Face ID + 密码。密码仅存本机（加盐哈希），忘记将无法找回。")
                }
            }
            .navigationTitle(ledger == nil ? "新建账本" : "编辑账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let l: Ledger
        if let existing = ledger {
            l = existing
            l.name = trimmed; l.symbolName = symbol; l.colorHex = colorHex
        } else {
            let order = (ledgers.map(\.sortOrder).max() ?? 0) + 1
            l = Ledger(name: trimmed, symbolName: symbol, colorHex: colorHex, isDefault: false, sortOrder: order)
            context.insert(l)
        }
        l.isPrivate = isPrivate
        if isPrivate {
            if !password.isEmpty { l.passwordHash = Ledger.hash(password) }  // else keep existing
        } else {
            l.passwordHash = nil
        }
        try? context.save()
        Haptics.tap()
        dismiss()
    }
}

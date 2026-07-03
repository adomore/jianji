import SwiftUI
import SwiftData

/// F8 自定义分类 (P1). PRD §4.6. Add / delete custom categories. Built-ins can't be
/// deleted; deleting a custom category reassigns its transactions to "其他" (never
/// deletes the bills).
struct CategoryManagementView: View {
    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showAdd = false
    @State private var addIsExpense = true

    private var expense: [Category] { categories.filter { $0.isExpense } }
    private var income: [Category] { categories.filter { !$0.isExpense } }

    var body: some View {
        List {
            section("支出分类", items: expense, isExpense: true)
            section("收入分类", items: income, isExpense: false)
        }
        .navigationTitle("分类管理").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddCategoryView(isExpense: addIsExpense, nextOrder: (categories.map(\.sortOrder).max() ?? 0) + 1)
                .environment(\.theme, t)
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [Category], isExpense: Bool) -> some View {
        Section {
            ForEach(items) { c in
                HStack(spacing: 12) {
                    Text(c.emoji).font(.system(size: 20))
                        .frame(width: 34, height: 34).background(c.tint, in: Circle())
                    Text(c.name)
                    Spacer()
                    if c.isBuiltin {
                        Text("内置").font(.system(size: 12)).foregroundStyle(t.ter)
                    }
                }
                .swipeActions {
                    if !c.isBuiltin {
                        Button(role: .destructive) { delete(c) } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
            Button { addIsExpense = isExpense; showAdd = true } label: {
                Label("添加分类", systemImage: "plus.circle.fill")
            }
        } header: { Text(title) }
    }

    /// Reassign this category's transactions to "其他" of the same side, then delete it.
    private func delete(_ c: Category) {
        let fallback = categories.first { $0.isExpense == c.isExpense && $0.name == "其他" }
        if let txs = c.transactions {
            for tx in txs { tx.category = fallback }
        }
        context.delete(c)
        try? context.save()
        Haptics.tap()
    }
}

/// Create a custom category: name + emoji + color, on the chosen side.
struct AddCategoryView: View {
    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let isExpense: Bool
    let nextOrder: Int

    @State private var name = ""
    @State private var emoji = "🏷️"
    @State private var colorHex = "FF9500"

    private let palette = ["FF9500", "007AFF", "FF2D55", "30B0C7", "AF52DE",
                           "FF3B30", "5856D6", "34C759", "00C7BE", "787880"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("图标")
                        Spacer()
                        TextField("emoji", text: $emoji)
                            .multilineTextAlignment(.trailing).font(.system(size: 24))
                            .frame(width: 60)
                            .onChange(of: emoji) { _, v in emoji = String(v.prefix(2)) }
                    }
                    HStack {
                        Text("名称")
                        TextField("分类名", text: $name).multilineTextAlignment(.trailing)
                    }
                }
                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                        ForEach(palette, id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                                .overlay(Circle().stroke(t.text, lineWidth: colorHex == hex ? 2.5 : 0).padding(-3))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    HStack(spacing: 12) {
                        Text(emoji).font(.system(size: 22))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: colorHex).opacity(0.16), in: Circle())
                        Text(name.isEmpty ? "分类名" : name).foregroundStyle(name.isEmpty ? t.ter : t.text)
                    }
                } header: { Text("预览") }
            }
            .navigationTitle(isExpense ? "新增支出分类" : "新增收入分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let c = Category(name: name.trimmingCharacters(in: .whitespaces),
                         emoji: emoji.isEmpty ? "🏷️" : emoji,
                         symbolName: "tag.fill", colorHex: colorHex, tintOpacity: 0.16,
                         isExpense: isExpense, sortOrder: nextOrder, isBuiltin: false)
        context.insert(c)
        try? context.save()
        Haptics.tap()
        dismiss()
    }
}

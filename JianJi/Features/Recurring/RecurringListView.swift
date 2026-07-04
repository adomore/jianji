import SwiftUI
import SwiftData

/// 周期账单 management — list of recurring templates with add / edit / pause / delete.
struct RecurringListView: View {
    @Environment(\.theme) private var t
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.createdAt, order: .reverse) private var rules: [RecurringRule]

    @State private var editing: RecurringRule?
    @State private var showNew = false

    var body: some View {
        List {
            if rules.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 40)).foregroundStyle(t.ter)
                        Text("还没有周期账单").font(.system(size: 15)).foregroundStyle(t.sec)
                        Text("房租、订阅、工资等固定收支，设一次自动记账。")
                            .font(.system(size: 13)).foregroundStyle(t.ter)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(rules) { r in
                        Button { editing = r } label: { row(r) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(r) } label: { Label("删除", systemImage: "trash") }
                                Button { r.isActive.toggle(); try? context.save() } label: {
                                    Label(r.isActive ? "暂停" : "启用",
                                          systemImage: r.isActive ? "pause" : "play")
                                }.tint(r.isActive ? .orange : .green)
                            }
                    }
                } footer: {
                    Text("到期账单会在打开 App 时自动补记，无需后台运行。")
                }
            }
        }
        .navigationTitle("周期账单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) { RecurringEditView(rule: nil).environment(\.theme, t) }
        .sheet(item: $editing) { r in RecurringEditView(rule: r).environment(\.theme, t) }
    }

    private func row(_ r: RecurringRule) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(symbol: r.category?.symbolName ?? "arrow.triangle.2.circlepath",
                         color: r.category?.color ?? t.accent, size: 38)
                .opacity(r.isActive ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(r.category?.name ?? "周期账单").font(.system(size: 16, weight: .medium))
                        .foregroundStyle(r.isActive ? t.text : t.sec)
                    if !r.isActive {
                        Text("已暂停").font(.system(size: 10, weight: .semibold)).foregroundStyle(t.ter)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(t.fill, in: Capsule())
                    }
                }
                Text(r.scheduleText + (r.note.isEmpty ? "" : " · " + r.note))
                    .font(.system(size: 12)).foregroundStyle(t.sec).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Fmt.signed(r.amount, isExpense: r.isExpense))
                .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                .foregroundStyle(r.isActive ? (r.isExpense ? t.red : t.green) : t.ter)
        }
        .padding(.vertical, 2)
    }

    private func delete(_ r: RecurringRule) {
        context.delete(r)
        try? context.save()
    }
}

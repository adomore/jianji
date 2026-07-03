import SwiftUI

/// Screen — 设置. PRD §5.1. Category management (P1) + about/privacy; P2 items shown
/// as "即将推出" placeholders so the information architecture is complete.
struct SettingsView: View {
    @Environment(\.theme) private var t

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { CategoryManagementView() } label: {
                        row("square.grid.2x2.fill", t.accent, "分类管理")
                    }
                } header: { Text("记账") }

                Section {
                    placeholder("chart.pie.fill", Color(hex: "5856D6"), "月度预算")
                    placeholder("square.and.arrow.up.fill", Color(hex: "34C759"), "导出 CSV")
                    placeholder("icloud.fill", Color(hex: "007AFF"), "iCloud 同步")
                } header: { Text("更多") } footer: { Text("以上功能将在后续版本中推出。") }

                Section {
                    NavigationLink { AboutView() } label: { row("info.circle.fill", t.sec, "关于「简记」") }
                }
            }
            .navigationTitle("设置")
            .safeAreaPadding(.bottom, 90)
        }
    }

    private func row(_ symbol: String, _ color: Color, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.white)
                .frame(width: 28, height: 28).background(color, in: RoundedRectangle(cornerRadius: 7))
            Text(title)
        }
    }

    private func placeholder(_ symbol: String, _ color: Color, _ title: String) -> some View {
        HStack {
            row(symbol, color, title)
            Spacer()
            Text("即将推出").font(.system(size: 13)).foregroundStyle(t.ter)
        }
    }
}

/// PRD §8 privacy promise, shown in the about page.
struct AboutView: View {
    @Environment(\.theme) private var t

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 56)).foregroundStyle(t.accent)
                    Text("简记").font(.system(size: 22, weight: .bold))
                    Text("版本 1.0").font(.system(size: 13)).foregroundStyle(t.sec)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section("隐私承诺") {
                bullet("无账号、无服务器，不收集任何数据。")
                bullet("所有账单只存在你的手机本地。")
                bullet("截图识别完全在本机进行，图片不会上传。")
            }

            Section {
                Text("删除 App 会同时删除全部数据（iCloud 同步为后续版本功能）。")
                    .font(.system(size: 13)).foregroundStyle(t.sec)
            }
        }
        .navigationTitle("关于").navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(t.green).font(.system(size: 15))
            Text(text).font(.system(size: 15))
        }
    }
}

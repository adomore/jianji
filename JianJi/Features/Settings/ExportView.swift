import SwiftUI
import SwiftData
import UIKit

/// 导出账单 — CSV (all bills) and a rendered summary image, both via the system share sheet.
struct ExportView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Transaction.date, order: .reverse) private var all: [Transaction]

    @State private var csvURL: URL?
    @State private var shareImage: Image?
    @State private var prepared = false

    private var t: Theme { Theme(scheme) }
    private var income: Decimal { all.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var expense: Decimal { all.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            Section {
                if let url = csvURL {
                    ShareLink(item: url) { label("tablecells.fill", Color(hex: "34C759"), "导出为 CSV 表格") }
                } else { preparing }
            } footer: {
                Text("包含全部账单：日期 / 类型 / 分类 / 金额 / 备注 / 账本，可用 Excel、Numbers 打开。")
            }

            Section {
                if let img = shareImage {
                    ShareLink(item: img, preview: SharePreview("简记账单汇总", image: img)) {
                        label("photo.fill", t.accent, "导出为图片")
                    }
                } else { preparing }
            } footer: {
                Text("生成一张账单汇总图，可保存到相册或分享。")
            }
        }
        .navigationTitle("导出账单")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !prepared { prepare(); prepared = true } }
    }

    private var preparing: some View {
        HStack(spacing: 10) { ProgressView(); Text("准备中…").foregroundStyle(t.sec) }
    }

    private func label(_ symbol: String, _ color: Color, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.white)
                .frame(width: 28, height: 28).background(color, in: RoundedRectangle(cornerRadius: 7))
            Text(title).foregroundStyle(t.text)
        }
    }

    @MainActor private func prepare() {
        csvURL = writeCSV()
        let renderer = ImageRenderer(content: summaryCard)
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }

    private func writeCSV() -> URL? {
        var rows = ["日期,类型,分类,金额,备注,账本"]
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"
        for tx in all {
            let date = df.string(from: tx.date)
            let type = tx.isExpense ? "支出" : "收入"
            let cat = tx.category?.name ?? "其他"
            let amt = String(format: "%.2f", NSDecimalNumber(decimal: tx.amount).doubleValue)   // no grouping commas
            let note = tx.note.replacingOccurrences(of: "\"", with: "\"\"")
            let ledger = tx.ledger?.name ?? ""
            rows.append("\(date),\(type),\(cat),\(amt),\"\(note)\",\(ledger)")
        }
        let csv = "\u{FEFF}" + rows.joined(separator: "\r\n")   // BOM so Excel reads UTF-8 CN
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("简记账单.csv")
        do { try csv.data(using: .utf8)?.write(to: url); return url } catch { return nil }
    }

    /// Rendered offscreen → fixed light palette (no environment dependency).
    private var summaryCard: some View {
        let balance = income - expense
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "yensign.circle.fill").font(.system(size: 26)).foregroundStyle(Color(hex: "FF9500"))
                Text("简记 · 账单汇总").font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
            }
            Divider()
            summaryRow("总收入", Fmt.money(income), Color(hex: "34C759"))
            summaryRow("总支出", Fmt.money(expense), .black)
            summaryRow("结余", Fmt.money(balance), balance >= 0 ? .black : Color(hex: "FF3B30"))
            Divider()
            Text("共 \(all.count) 笔记录").font(.system(size: 13)).foregroundStyle(.gray)
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .background(Color.white)
    }

    private func summaryRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(.gray)
            Spacer()
            Text(value).font(.system(size: 17, weight: .semibold)).monospacedDigit().foregroundStyle(color)
        }
    }
}

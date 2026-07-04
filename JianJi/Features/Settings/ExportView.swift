import SwiftUI
import SwiftData
import UIKit

/// 导出账单 — CSV (all bills) and a rendered summary image, both via the system share sheet.
struct ExportView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Transaction.date, order: .reverse) private var all: [Transaction]
    @EnvironmentObject private var privacy: PrivacyGate

    @State private var csvURL: URL?
    @State private var shareImage: Image?
    @State private var prepared = false

    private var t: Theme { Theme(scheme) }
    /// Never export hidden private bills unless the user has revealed them this session.
    private var visible: [Transaction] { all.filter { privacy.revealed || !$0.isPrivate } }
    private var income: Decimal { visible.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var expense: Decimal { visible.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }

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
        for tx in visible {
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

    private let exportCap = 80

    private var exportDays: [(day: Date, items: [Transaction])] {
        let capped = Array(visible.prefix(exportCap))
        let g = Dictionary(grouping: capped) { Calendar.current.startOfDay(for: $0.date) }
        return g.keys.sorted(by: >).map { (day: $0, items: g[$0]!.sorted { $0.createdAt > $1.createdAt }) }
    }

    private var rangeText: String {
        guard let first = visible.first?.date, let last = visible.last?.date else { return "共 0 笔" }
        return "\(Fmt.dayMonth(last)) – \(Fmt.dayMonth(first)) · 共 \(visible.count) 笔"
    }

    /// Rendered offscreen → fixed light palette (no environment dependency). Summary + 明细.
    private var summaryCard: some View {
        let balance = income - expense
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "yensign.circle.fill").font(.system(size: 26)).foregroundStyle(Color(hex: "FF9500"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("简记 · 账单汇总").font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
                    Text(rangeText).font(.system(size: 12)).foregroundStyle(.gray)
                }
                Spacer()
            }
            .padding(.bottom, 14)

            HStack(spacing: 0) {
                totalCol("总收入", Fmt.money(income), Color(hex: "34C759"))
                totalCol("总支出", Fmt.money(expense), .black)
                totalCol("结余", Fmt.money(balance), balance >= 0 ? .black : Color(hex: "FF3B30"))
            }
            .padding(.vertical, 14)
            .background(Color(hex: "F5F5F7"), in: RoundedRectangle(cornerRadius: 12))

            Text("明细").font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
                .padding(.top, 18).padding(.bottom, 2)

            ForEach(exportDays, id: \.day) { group in
                HStack(spacing: 6) {
                    Text(Fmt.dayMonth(group.day)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                    Text(Fmt.weekdayShort(group.day)).font(.system(size: 12)).foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.top, 12).padding(.bottom, 4)
                ForEach(group.items) { tx in detailRow(tx) }
            }

            if visible.count > exportCap {
                Text("仅显示最近 \(exportCap) 笔，共 \(visible.count) 笔")
                    .font(.system(size: 11)).foregroundStyle(.gray).padding(.top, 12)
            }
            Text("由「简记」导出")
                .font(.system(size: 11)).foregroundStyle(Color(hex: "BBBBBB"))
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 18)
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .background(Color.white)
    }

    private func totalCol(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .semibold)).monospacedDigit().foregroundStyle(color)
            Text(label).font(.system(size: 12)).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailRow(_ tx: Transaction) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tx.category?.symbolName ?? "shippingbox.fill")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(tx.category?.color ?? Color(hex: "787880"), in: Circle())
            Text(tx.category?.name ?? "其他").font(.system(size: 13)).foregroundStyle(.black)
            if !tx.note.isEmpty {
                Text(tx.note).font(.system(size: 12)).foregroundStyle(.gray).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text((tx.isExpense ? "-" : "+") + Fmt.amount(tx.amount))
                .font(.system(size: 13, weight: .medium)).monospacedDigit()
                .foregroundStyle(tx.isExpense ? .black : Color(hex: "34C759"))
        }
        .padding(.vertical, 3)
    }
}

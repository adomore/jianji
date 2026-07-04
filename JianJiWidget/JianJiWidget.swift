import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snap: BudgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snap: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snap: BudgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snap: BudgetSnapshot.load() ?? .placeholder)
        // The app reloads timelines on every change; this hourly policy is just a fallback so
        // the "本月" rolls over even if the app isn't opened.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

private let brandOrange = Color(red: 1, green: 0.584, blue: 0)

private func money(_ v: Double, compact: Bool = false) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    f.maximumFractionDigits = compact ? 0 : 2
    f.minimumFractionDigits = compact ? 0 : 2
    return "¥" + (f.string(from: NSNumber(value: v)) ?? "0")
}

struct JianJiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var s: BudgetSnapshot { entry.snap }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text("本月支出").font(.system(size: 11)).foregroundStyle(.secondary)
            Text(money(s.expense, compact: true))
                .font(.system(size: 22, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(s.overBudget ? .red : .primary)
            if s.budget > 0 { progress }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .top, spacing: 16) {
                stat("本月支出", money(s.expense, compact: true), s.overBudget ? .red : .primary)
                stat("本月收入", money(s.income, compact: true), .green)
                stat(s.remaining >= 0 ? "预算剩余" : "已超支",
                     s.budget > 0 ? money(abs(s.remaining), compact: true) : "不限",
                     s.budget > 0 ? (s.remaining >= 0 ? brandOrange : .red) : .secondary)
            }
            Spacer(minLength: 0)
            if s.budget > 0 { progress }
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "yensign.circle.fill").foregroundStyle(brandOrange).font(.system(size: 13))
            Text(s.ledgerName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Spacer()
            Text(s.monthLabel).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(s.overBudget ? Color.red : brandOrange)
                    .frame(width: max(4, geo.size.width * CGFloat(s.ratio)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Widget

struct JianJiWidget: Widget {
    let kind = "JianJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            JianJiWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("简记 · 本月")
        .description("本月支出 / 收入与预算进度，一眼可见。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

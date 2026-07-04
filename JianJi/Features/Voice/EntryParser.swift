import Foundation

/// Keyword-rule parser for voice transcripts and OCR text. PRD §4.3 / §4.4.
///
/// The keyword table is deliberately kept as one central config (PRD §9.2): when
/// WeChat/Alipay screenshots change layout, only this table needs editing.
enum EntryParser {

    /// Category keyword map (PRD §4.3). Order matters: first hit wins.
    static let keywordMap: [(category: String, keywords: [String])] = [
        ("餐饮", ["吃", "饭", "餐", "早餐", "午餐", "午饭", "晚餐", "晚饭", "中餐", "外卖", "奶茶",
                "咖啡", "餐厅", "美食", "食堂", "快餐", "夜宵", "宵夜", "零食", "下午茶", "火锅",
                "烧烤", "喝", "水果", "菜"]),
        ("交通", ["打车", "地铁", "公交", "滴滴", "加油", "停车", "高铁", "火车", "机票", "车票", "共享单车", "过路费"]),
        ("购物", ["买", "淘宝", "京东", "拼多多", "超市", "商场", "网购", "衣服", "鞋"]),
        ("娱乐", ["电影", "游戏", "KTV", "唱歌", "演唱会", "娱乐", "旅游", "门票"]),
        ("医疗", ["药", "医院", "挂号", "诊所", "体检", "看病"]),
        ("日用", ["日用", "纸巾", "洗", "牙膏", "洗衣", "家居"]),
        ("住房", ["房租", "水电", "物业", "房贷", "电费", "水费", "燃气"]),
    ]

    /// Wording that flips 支出/收入 regardless of the segment's current value.
    static let incomeHints = ["收入", "工资", "薪", "进账", "红包", "报销", "退款", "利息", "分红", "奖金", "转入", "收到", "赚"]
    static let expenseHints = ["支出", "花了", "花", "付", "买", "消费", "支付", "转出", "交了", "充值", "缴"]

    static func parse(_ text: String, isExpense defaultExpense: Bool, categories: [Category], source: EntrySource) -> EntryDraft {
        let isExpense = detectIsExpense(text, default: defaultExpense)
        let amount = parseAmount(text)
        let categoryName = parseCategory(text, isExpense: isExpense, categories: categories)
        let date = parseDate(text)
        let note = parseNote(text, categoryName: categoryName)
        return EntryDraft(isExpense: isExpense, amount: amount, categoryName: categoryName,
                          date: date, note: note, rawText: text, source: source)
    }

    /// Infer 支出/收入 from the phrase; income wins if both appear, else fall back to the segment.
    static func detectIsExpense(_ text: String, default def: Bool) -> Bool {
        if incomeHints.contains(where: { text.contains($0) }) { return false }
        if expenseHints.contains(where: { text.contains($0) }) { return true }
        return def
    }

    // MARK: amount

    /// Matches "23", "23.5", and "23块5" (元 + 角). First-version supports Arabic digits only.
    static func parseAmount(_ text: String) -> Decimal? {
        // "23块5" / "23元5" → 23.5
        if let m = firstMatch(text, #"([0-9]+)\s*[块元]\s*([0-9])"#), m.count == 3,
           let yuan = Decimal(string: m[1]), let jiao = Decimal(string: m[2]) {
            return yuan + jiao / 10
        }
        // plain number, optional decimals
        if let m = firstMatch(text, #"([0-9]+(?:\.[0-9]{1,2})?)"#), m.count == 2,
           let d = Decimal(string: m[1]), d > 0 {
            return d
        }
        return nil
    }

    // MARK: category

    static func parseCategory(_ text: String, isExpense: Bool, categories: [Category]) -> String {
        let available = Set(categories.filter { $0.isExpense == isExpense }.map(\.name))
        if isExpense {
            for entry in keywordMap where available.contains(entry.category) {
                if entry.keywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
                    return entry.category
                }
            }
        } else {
            // Simple income hints.
            if text.contains("工资") || text.contains("薪") { return available.contains("工资") ? "工资" : "其他" }
            if text.contains("红包") { return available.contains("红包") ? "红包" : "其他" }
            if text.contains("利息") || text.contains("理财") || text.contains("基金") {
                return available.contains("理财") ? "理财" : "其他"
            }
        }
        return "其他"
    }

    // MARK: date

    static func parseDate(_ text: String) -> Date {
        let cal = Calendar.current
        if text.contains("前天") { return cal.date(byAdding: .day, value: -2, to: .now) ?? .now }
        if text.contains("昨天") { return cal.date(byAdding: .day, value: -1, to: .now) ?? .now }
        return .now
    }

    // MARK: note

    /// Use the first matched keyword as a short note (matches the PRD example where
    /// "昨天打车花了23块" → 备注：打车). Falls back to empty.
    static func parseNote(_ text: String, categoryName: String) -> String {
        for entry in keywordMap where entry.category == categoryName {
            if let hit = entry.keywords.first(where: { text.contains($0) }) { return hit }
        }
        return ""
    }

    // MARK: regex helper

    private static func firstMatch(_ text: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        return (0..<m.numberOfRanges).compactMap {
            guard let r = Range(m.range(at: $0), in: text) else { return "" }
            return String(text[r])
        }
    }
}

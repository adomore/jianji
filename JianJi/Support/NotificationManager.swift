import Foundation
import SwiftData
import UserNotifications

/// Local notifications only — no server, no account, no push entitlement. Used for the
/// budget over-spend reminder (1.1). Authorization is requested lazily when the user turns
/// the reminder on in 设置 → 月度预算.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() { super.init() }

    private let center = UNUserNotificationCenter.current()

    /// Called once at launch so notifications also show while the app is foregrounded.
    func configure() { center.delegate = self }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    /// Which budget alert (if any) a spend ratio warrants. Pure — unit-tested directly.
    enum BudgetAlert: Equatable { case warn, over }
    static func alert(forRatio ratio: Double) -> BudgetAlert? {
        if ratio >= 1.0 { return .over }
        if ratio >= 0.8 { return .warn }
        return nil
    }

    /// Fire a one-time notification for each budget threshold (80% warning, 100% over) as it
    /// is newly crossed within a given month. Tracked per (month, threshold) so it never spams;
    /// if spend later drops back under 80% (budget raised / bill deleted) the flags reset so a
    /// re-crossing can alert again.
    func evaluateBudget(monthExpense: Decimal, budget: Decimal, monthKey: String) {
        guard budget > 0 else { return }
        let ratio = (monthExpense as NSDecimalNumber).doubleValue / (budget as NSDecimalNumber).doubleValue
        let warnKey = "budgetAlert.warn.\(monthKey)"
        let overKey = "budgetAlert.over.\(monthKey)"
        let d = UserDefaults.standard

        switch Self.alert(forRatio: ratio) {
        case .none:                             // back under the line → allow future re-alerts
            d.set(false, forKey: warnKey); d.set(false, forKey: overKey)
        case .over:
            fireOnce(key: overKey,
                     title: "本月支出已超预算",
                     body: "本月已支出 \(Fmt.money(monthExpense))，超过预算 \(Fmt.money(budget))。")
        case .warn:
            fireOnce(key: warnKey,
                     title: "预算即将用完",
                     body: "本月已用预算的 \(Int(ratio * 100))%，注意控制支出。")
        }
    }

    private func fireOnce(key: String, title: String, body: String) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: key) else { return }
        d.set(true, forKey: key)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: key,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        center.add(req)
    }

    // MARK: foreground presentation
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// Recomputes the active book's current-month expense (excluding private bills, which must
/// never surface on a lock screen) and hands it to `NotificationManager`. Cheap; safe to call
/// on launch, on returning to the foreground, and after each new bill.
enum BudgetEvaluator {
    static func run(_ context: ModelContext) {
        let d = UserDefaults.standard
        guard d.bool(forKey: "budgetReminderEnabled") else { return }
        let budget = Decimal(d.double(forKey: "monthlyBudget"))
        guard budget > 0 else { return }

        let activeID = d.string(forKey: ActiveLedger.storageKey) ?? ""
        let cal = Calendar.current
        let ledgers = (try? context.fetch(FetchDescriptor<Ledger>())) ?? []
        let active = ActiveLedger.resolve(ledgers, activeID: activeID)
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let monthExpense = all.filter {
            $0.isExpense && !$0.isPrivate && $0.ledger?.id == active?.id
            && cal.isDate($0.date, equalTo: .now, toGranularity: .month)
        }.reduce(Decimal(0)) { $0 + $1.amount }

        NotificationManager.shared.evaluateBudget(monthExpense: monthExpense,
                                                  budget: budget,
                                                  monthKey: Fmt.yearMonth(.now))
    }
}

import SwiftUI
import LocalAuthentication

/// Session unlock state for private 账本. A book is "open" if it isn't private or has been
/// unlocked (Face ID + password) this session; everything re-locks on background.
@MainActor
final class LedgerLock: ObservableObject {
    @Published var unlocked: Set<UUID> = []

    func isOpen(_ ledger: Ledger?) -> Bool {
        guard let ledger else { return true }
        return !ledger.isPrivate || unlocked.contains(ledger.id)
    }

    func relock() { unlocked.removeAll() }

    /// Verify the password first, then Face ID; unlock only when BOTH pass.
    func unlock(_ ledger: Ledger, password: String, onResult: @escaping (Bool, String?) -> Void) {
        guard ledger.matches(password: password) else { onResult(false, "密码错误"); return }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "输入手机密码"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            unlocked.insert(ledger.id); onResult(true, nil)   // no biometrics/passcode → password alone
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "打开「\(ledger.name)」需要验证身份") { ok, _ in
            Task { @MainActor in
                if ok { self.unlocked.insert(ledger.id); onResult(true, nil) }
                else { onResult(false, "身份验证未通过") }
            }
        }
    }
}

/// Lock gate shown in place of a private book's content until it's opened.
struct LedgerUnlockView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var lock: LedgerLock
    let ledger: Ledger
    var onUnlocked: () -> Void = {}

    @State private var password = ""
    @State private var error: String?

    private var t: Theme { Theme(scheme) }

    var body: some View {
        VStack(spacing: 16) {
            CategoryIcon(symbol: ledger.symbolName, color: ledger.color, size: 56)
            Text("「\(ledger.name)」已加密")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(t.text)
            Text("需 Face ID + 密码才能打开").font(.system(size: 13)).foregroundStyle(t.sec)

            SecureField("输入账本密码", text: $password)
                .textContentType(.password)
                .multilineTextAlignment(.center)
                .font(.system(size: 17))
                .padding(.horizontal, 16).frame(height: 46)
                .frame(maxWidth: 260)
                .background(t.fill, in: RoundedRectangle(cornerRadius: 12))
                .onSubmit(verify)

            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(t.red)
            }

            Button(action: verify) {
                Text("解锁").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: 260).frame(height: 48)
                    .background(t.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(password.isEmpty)
            .opacity(password.isEmpty ? 0.5 : 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.groupBg)
    }

    private func verify() {
        guard !password.isEmpty else { return }
        lock.unlock(ledger, password: password) { ok, msg in
            if ok { onUnlocked() } else { error = msg; password = "" }
        }
    }
}

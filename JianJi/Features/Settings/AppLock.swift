import SwiftUI
import LocalAuthentication

/// App-level privacy lock. When enabled in 设置, the whole app is covered by a lock
/// screen until the user passes Face ID / Touch ID / passcode; it re-locks on background.
@MainActor
final class AppLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var failed = false

    func authenticate() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "输入密码"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // No passcode / biometrics configured → nothing to authenticate against.
            isUnlocked = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "查看完整账单需要验证身份") { ok, _ in
            Task { @MainActor in
                self.isUnlocked = ok
                self.failed = !ok
            }
        }
    }

    func lock() { isUnlocked = false; failed = false }
}

/// Full-screen cover shown while the app is locked.
struct LockView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var lock: AppLock
    private var t: Theme { Theme(scheme) }

    var body: some View {
        ZStack {
            t.groupBg.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44)).foregroundStyle(t.accent)
                Text("账单已锁定").font(.system(size: 20, weight: .semibold)).foregroundStyle(t.text)
                Text("验证身份后查看完整账单").font(.system(size: 14)).foregroundStyle(t.sec)
                Button { lock.authenticate() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text(lock.failed ? "重试解锁" : "解锁")
                    }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 28).frame(height: 48)
                    .background(t.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .onAppear { lock.authenticate() }
    }
}

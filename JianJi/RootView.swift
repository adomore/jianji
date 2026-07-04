import SwiftUI

enum Tab: Int { case ledger, list, charts, settings }

/// App shell: the three tabs plus the custom floating "＋" tab bar (PRD §5.1).
/// The bar is drawn by hand (rather than a system `TabView`) because of the centered
/// floating add button and the blurred bar — matching the prototype's bottom bar exactly.
struct RootView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("privacyLockEnabled") private var lockEnabled = false
    @StateObject private var appLock = AppLock()
    @State private var tab: Tab = .list
    @State private var showAdd = false
    @State private var startInVoice = false

    private var t: Theme { Theme(scheme) }
    private var locked: Bool { lockEnabled && !appLock.isUnlocked }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .ledger:   LedgerView()
                case .list:     HomeView(onAdd: { openAdd() })
                case .charts:   ChartsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(
                tab: $tab,
                onAdd: { openAdd(voice: false) },
                onAddLongPress: { openAdd(voice: true) }
            )
            .environment(\.theme, t)
        }
        .background(t.groupBg.ignoresSafeArea())
        .environment(\.theme, t)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAdd) {
            AddSheetView(startInVoice: startInVoice)
                .environment(\.theme, t)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(14)
        }
        // Privacy lock (设置 → 账单隐私保护): cover everything until authenticated.
        .overlay {
            if locked { LockView(lock: appLock).environment(\.theme, t) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && lockEnabled { appLock.lock() }
        }
        .onChange(of: lockEnabled) { _, _ in
            appLock.isUnlocked = true   // toggling in 设置 shouldn't lock you out immediately
        }
    }

    private func openAdd(voice: Bool = false) {
        startInVoice = voice
        showAdd = true
        Haptics.tap()
    }
}

/// Bottom tab bar with the centered floating orange add button.
private struct TabBar: View {
    @Environment(\.theme) private var t
    @Binding var tab: Tab
    var onAdd: () -> Void
    var onAddLongPress: () -> Void

    var body: some View {
        ZStack {
            // Blurred bar background with hairline top border — bleeds under the
            // home indicator to the screen's bottom edge (随手记 style), so no page
            // background shows below the bar.
            Rectangle()
                .fill(.regularMaterial)
                .overlay(t.bar)
                .overlay(alignment: .top) {
                    Rectangle().fill(t.sep).frame(height: 0.5)
                }
                .frame(height: 82)
                .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 0) {
                item(.ledger, symbol: "books.vertical.fill", label: "账本")
                item(.list, symbol: "list.bullet", label: "明细")
                Spacer().frame(width: 72)     // center slot for the + button (明细 ↔ 图表)
                item(.charts, symbol: "chart.bar.fill", label: "图表")
                item(.settings, symbol: "gearshape.fill", label: "设置")
            }
            .frame(height: 82)
            .padding(.bottom, 18)

            // Floating add button — lifted above the bar.
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(t.accent, in: Circle())
                    .shadow(color: t.accent.opacity(0.4), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(PressableStyle(scale: 0.94))
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in onAddLongPress() })
            .offset(y: -41)
            .accessibilityLabel("记一笔")
            .accessibilityHint("长按可直接进入语音记账")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
    }

    @ViewBuilder
    private func item(_ target: Tab, symbol: String, label: String) -> some View {
        let selected = tab == target
        Button {
            tab = target
            Haptics.tap()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                Text(label).font(.system(size: 10, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? t.accent : t.sec)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

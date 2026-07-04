import SwiftUI

/// In-app splash shown over the UI at cold launch.
///
/// The system launch screen (LaunchScreen.storyboard) can only reliably render
/// plain text/color — referencing an asset-catalog image from a launch storyboard
/// fails to load on device (blank/white). So the branded "¥ 货币纹路" art is shown
/// here instead: SwiftUI loads `Image("LaunchArt")` at runtime, which is reliable,
/// then fades out into the app. Net effect matches 随手记's "启动图停留一下再进".
struct SplashView: View {
    var onFinish: () -> Void
    @State private var visible = true

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("LaunchArt")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
        }
        .opacity(visible ? 1 : 0)
        .task {
            // The system launch screen (LaunchScreen.storyboard) shows the same ¥ + 简记
            // lockup in the same positions, so the hand-off is seamless — only the 纹路
            // texture fades in around the ¥. Hold long enough to read it, then fade in.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeOut(duration: 0.4)) { visible = false }
            try? await Task.sleep(nanoseconds: 420_000_000)
            onFinish()
        }
        .accessibilityElement()
        .accessibilityLabel("简记")
    }
}

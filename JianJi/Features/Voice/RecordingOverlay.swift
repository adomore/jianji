import SwiftUI

/// Full-screen recording UI: waveform animation + live transcript + stop button.
/// Shown while `speech.isRecording`. PRD §4.3 (显示声波动画 + 实时转出的文字).
struct RecordingOverlay: View {
    @Environment(\.theme) private var t
    @ObservedObject var speech: SpeechManager
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { speech.stop() }

            VStack(spacing: 28) {
                Spacer()

                Text(speech.transcript.isEmpty ? "请开始说话…" : speech.transcript)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.default, value: speech.transcript)

                // Simple animated waveform.
                HStack(spacing: 5) {
                    ForEach(0..<9, id: \.self) { i in
                        Capsule()
                            .fill(t.accent)
                            .frame(width: 5, height: animate ? barHeights[i] : 8)
                            .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.06),
                                       value: animate)
                    }
                }
                .frame(height: 60)

                Spacer()

                Button { speech.stop() } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(t.accent).frame(width: 76, height: 76)
                            RoundedRectangle(cornerRadius: 6).fill(.white).frame(width: 26, height: 26)
                        }
                        Text("点击完成").font(.system(size: 14)).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 60)
            }
        }
        .onAppear { animate = true }
    }

    private let barHeights: [CGFloat] = [18, 34, 52, 30, 60, 26, 46, 36, 20]
}

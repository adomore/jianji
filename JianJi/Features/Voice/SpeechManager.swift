import Foundation
import Speech
import AVFoundation

/// Live speech-to-text via Apple's Speech framework. PRD §4.3 / §7.
/// Prefers on-device recognition (`requiresOnDeviceRecognition`) when supported — no
/// network, more private. Handles the two permission prompts (mic + speech) and the
/// denied fallback.
@MainActor
final class SpeechManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinished: ((String) -> Void)?

    /// Ask for permissions, then begin recording. Calls `onDenied` if either permission
    /// is refused, and `onFinished(transcript)` after `stop()`.
    func requestAndStart(onDenied: @escaping () -> Void, onFinished: @escaping (String) -> Void) {
        self.onFinished = onFinished
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else { onDenied(); return }
                self.requestMicAndStart(onDenied: onDenied)
            }
        }
    }

    private func requestMicAndStart(onDenied: @escaping () -> Void) {
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { onDenied(); return }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else { return }

        // Reset any prior session.
        task?.cancel(); task = nil
        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil || (result?.isFinal ?? false) {
                        self?.finish()
                    }
                }
            }
        } catch {
            isRecording = false
        }
    }

    /// User tapped stop — end audio and deliver the transcript.
    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        request?.endAudio()
        // Give the recognizer a beat to emit the final result; if not, deliver what we have.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard isRecording || task != nil else { return }
        let text = transcript
        cleanup()
        let cb = onFinished
        onFinished = nil
        cb?(text)
    }

    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request = nil
        task?.cancel(); task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

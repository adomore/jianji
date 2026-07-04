import SwiftUI
import PhotosUI
import UIKit

/// Attaches a `PhotosPicker` (multi-select ≤ 9, no album permission needed — PRD §4.4 加分项)
/// and runs OCR on each picked image, producing an `EntryDraft` per image.
struct PhotosConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let isExpense: Bool
    let categories: [Category]
    var onDrafts: ([EntryDraft]) -> Void

    @Environment(\.theme) private var t
    @State private var selection: [PhotosPickerItem] = []
    @State private var processing = false

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $selection,
                          maxSelectionCount: 9, matching: .images)
            .onChange(of: selection) { _, items in
                guard !items.isEmpty else { return }
                Task { await process(items) }
            }
            .overlay { if processing { processingOverlay } }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.3)
                Text("识别中…").font(.system(size: 15)).foregroundStyle(.white)
                Text("图片全程本地识别，不会离开你的手机")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(28)
            .background(Color(hex: "1E1E20").opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func process(_ items: [PhotosPickerItem]) async {
        processing = true
        var drafts: [EntryDraft] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                let lines = await OCRService.recognize(img)
                drafts.append(OCRService.makeDraft(from: lines, isExpense: isExpense, categories: categories))
            }
        }
        processing = false
        selection = []
        if !drafts.isEmpty { onDrafts(drafts) }
    }
}

extension View {
    func photosConfirm(isPresented: Binding<Bool>, isExpense: Bool,
                       categories: [Category], onDrafts: @escaping ([EntryDraft]) -> Void) -> some View {
        modifier(PhotosConfirmModifier(isPresented: isPresented, isExpense: isExpense,
                                       categories: categories, onDrafts: onDrafts))
    }
}

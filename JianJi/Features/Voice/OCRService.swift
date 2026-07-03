import Foundation
import Vision
import UIKit

/// On-device OCR for payment screenshots. PRD §4.4. Fully local — images never leave the
/// device (`VNRecognizeTextRequest`, no network). Returns recognized lines with their
/// bounding boxes so the amount picker can prefer the largest (tallest) text.
enum OCRService {

    struct Line {
        let text: String
        let height: CGFloat   // normalized bbox height; larger = bigger on-screen text
    }

    /// Recognize text in an image. `recognitionLevel = .accurate`, zh-Hans + en.
    static func recognize(_ image: UIImage) async -> [Line] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let lines: [Line] = (req.results as? [VNRecognizedTextObservation] ?? []).compactMap { obs in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return Line(text: top.string, height: obs.boundingBox.height)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    /// Turn recognized lines into a draft. Amount = largest-text money-looking line;
    /// merchant = line after a "收款方/商户/付款给" keyword; date parsed from any line.
    static func makeDraft(from lines: [Line], isExpense: Bool, categories: [Category]) -> EntryDraft {
        let fullText = lines.map(\.text).joined(separator: "\n")

        let amount = bestAmount(from: lines)
        let merchant = merchant(from: lines)
        let date = EntryParser.parseDate(fullText) // (also handles 今天/昨天)
        let parsedDate = screenshotDate(from: fullText) ?? date
        let category = EntryParser.parseCategory(merchant.isEmpty ? fullText : merchant,
                                                 isExpense: isExpense, categories: categories)

        return EntryDraft(isExpense: isExpense, amount: amount, categoryName: category,
                          date: parsedDate, note: merchant, rawText: fullText, source: .image)
    }

    // Prefer money-looking candidates, tie-broken by tallest bounding box (PRD §4.4).
    private static func bestAmount(from lines: [Line]) -> Decimal? {
        let candidates: [(Decimal, CGFloat)] = lines.compactMap { line in
            guard let value = moneyValue(in: line.text) else { return nil }
            return (value, line.height)
        }
        return candidates.max { $0.1 < $1.1 }?.0
    }

    private static func moneyValue(in text: String) -> Decimal? {
        // ¥25.00, -25.00, 25.00 etc.
        guard let re = try? NSRegularExpression(pattern: #"[-¥￥]?\s*([0-9]+(?:\.[0-9]{1,2})?)"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        // Require a currency cue so we don't grab order numbers / phone digits.
        let hasCue = text.contains("¥") || text.contains("￥") || text.contains("元") || text.contains("-")
        guard hasCue, let m = re.firstMatch(in: text, range: range),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return Decimal(string: String(text[r]))
    }

    private static func merchant(from lines: [Line]) -> String {
        let keywords = ["收款方", "商户全称", "商户名称", "付款给", "商户"]
        for (i, line) in lines.enumerated() {
            for kw in keywords where line.text.contains(kw) {
                // Merchant may be on the same line after "：" or on the next line.
                if let after = line.text.components(separatedBy: CharacterSet(charactersIn: "：:")).last,
                   after != line.text, !after.trimmingCharacters(in: .whitespaces).isEmpty {
                    return after.trimmingCharacters(in: .whitespaces)
                }
                if i + 1 < lines.count { return lines[i + 1].text }
            }
        }
        return ""
    }

    private static func screenshotDate(from text: String) -> Date? {
        let patterns = ["yyyy年M月d日 HH:mm", "yyyy年M月d日", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"]
        guard let re = try? NSRegularExpression(pattern: #"(\d{4})[年\-](\d{1,2})[月\-](\d{1,2})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard re.firstMatch(in: text, range: range) != nil else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        for p in patterns {
            f.dateFormat = p
            if let d = firstDate(text, formatter: f) { return d }
        }
        return nil
    }

    private static func firstDate(_ text: String, formatter: DateFormatter) -> Date? {
        for line in text.components(separatedBy: "\n") {
            if let d = formatter.date(from: line.trimmingCharacters(in: .whitespaces)) { return d }
        }
        return nil
    }
}

import Foundation
import SwiftData
import SwiftUI
import CryptoKit

/// 账本 — a named book that transactions belong to. Local-only multiple books
/// (single user; shared/family books stay out of scope per PRD §1.4).
@Model
final class Ledger {
    var id: UUID = UUID()
    var name: String = "默认账本"
    var symbolName: String = "books.vertical.fill"
    var colorHex: String = "FF9500"
    /// The built-in book that can't be deleted; deleting any other book reassigns its
    /// transactions here (never deletes bills), mirroring the category "其他" rule.
    var isDefault: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    /// Private book: needs Face ID + password to open. `passwordHash` is a salted SHA-256.
    var isPrivate: Bool = false
    var passwordHash: String?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.ledger)
    var transactions: [Transaction]? = []

    init(name: String,
         symbolName: String = "books.vertical.fill",
         colorHex: String = "FF9500",
         isDefault: Bool = false,
         sortOrder: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    var color: Color { Color(hex: colorHex) }

    /// Salted SHA-256 of a password. (Local-only "hide from snooping" factor, paired with
    /// Face ID — not a substitute for Keychain-grade secrets.)
    static func hash(_ password: String) -> String {
        let salted = "jianji.ledger.v1|" + password
        let digest = SHA256.hash(data: Data(salted.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func matches(password: String) -> Bool {
        guard let passwordHash else { return false }
        return Ledger.hash(password) == passwordHash
    }
}

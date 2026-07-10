//
//  TokenPiece.swift
//

import Foundation

struct TokenPiece: Sendable, Equatable, Hashable, Identifiable {
    let id: Int
    let text: String

    // Hash by id only (token identities are stable; text may decode slightly
    // differently across tokenizer versions). Documented for ForEach usage.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TokenPiece, rhs: TokenPiece) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text
    }
}
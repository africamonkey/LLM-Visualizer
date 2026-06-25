//
//  TokenCandidate.swift
//

import Foundation

struct TokenCandidate: Sendable, Equatable, Hashable, Identifiable {
    let id: Int
    let text: String
    let probability: Double
}
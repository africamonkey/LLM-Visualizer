//
//  TokenCandidateTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

struct TokenCandidateTests {

    @Test func storesAllFields() {
        let c = TokenCandidate(id: 42, text: "好", probability: 0.32)
        #expect(c.id == 42)
        #expect(c.text == "好")
        #expect(c.probability == 0.32)
    }

    @Test func equality() {
        let a = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let b = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let c = TokenCandidate(id: 2, text: "x", probability: 0.5)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func hashableForSetUse() {
        let a = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let b = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let set: Set<TokenCandidate> = [a, b]
        #expect(set.count == 1)
    }
}
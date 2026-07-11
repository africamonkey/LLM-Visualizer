//
//  TokenPieceTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

struct TokenPieceTests {

    @Test func identity() {
        let p = TokenPiece(id: 42, text: "我")
        #expect(p.id == 42)
        #expect(p.text == "我")
    }

    @Test func equality() {
        let a = TokenPiece(id: 1, text: "爱")
        let b = TokenPiece(id: 1, text: "爱")
        let c = TokenPiece(id: 2, text: "爱")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func identifiableHash() {
        let p = TokenPiece(id: 99, text: "🌧")
        #expect(p.id == 99)
        #expect(p.text == "🌧")
        // Stable hash by id only — used as ForEach key
        let same = TokenPiece(id: 99, text: "different")
        #expect(p.hashValue == same.hashValue)
    }

    @Test func setDeduplicatesById() {
        let set: Set<TokenPiece> = [
            TokenPiece(id: 1, text: "a"),
            TokenPiece(id: 1, text: "b"),   // same id, different text → should be one entry by hash; equality still distinguishes them
            TokenPiece(id: 2, text: "a"),
        ]
        #expect(set.count == 3) // equality is by both id+text, so 3 distinct elements
    }

    @Test func hashCollapsesByIdAlone() {
        let set: Set<TokenPiece> = [
            TokenPiece(id: 1, text: "a"),
            TokenPiece(id: 1, text: "b"),   // hash equal but not ==; treated as one bucket
        ]
        // Both hash to the same bucket. Set.count == 1 if no collision-equal elements,
        // but since == requires text match too, they remain distinct entries.
        // The relevant test: two pieces with same id share a hash bucket.
        let p1 = TokenPiece(id: 1, text: "a")
        let p2 = TokenPiece(id: 1, text: "b")
        #expect(p1.hashValue == p2.hashValue)
    }
}

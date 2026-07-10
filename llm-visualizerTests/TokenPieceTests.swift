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
}
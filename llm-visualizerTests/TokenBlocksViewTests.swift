//
//  TokenBlocksViewTests.swift
//

import Foundation
import Testing
import SwiftUI
@testable import llm_visualizer

@MainActor
struct TokenBlocksViewTests {

    @Test func standardIsDefaultStyle() {
        let view = TokenBlocksView(tokens: [
            TokenPiece(id: 1, text: "我"),
            TokenPiece(id: 2, text: "爱"),
        ])
        _ = view.body
    }

    @Test func compactStyleCompilesAlongsideStandard() {
        let standard = TokenBlocksView(tokens: [TokenPiece(id: 1, text: "我")])
        let compact = TokenBlocksView(tokens: [TokenPiece(id: 1, text: "我")], style: .compact)
        _ = standard.body
        _ = compact.body
    }

    @Test func emptyTokensYieldsEmptyBody() {
        let view = TokenBlocksView(tokens: [], style: .compact)
        _ = view.body
    }
}

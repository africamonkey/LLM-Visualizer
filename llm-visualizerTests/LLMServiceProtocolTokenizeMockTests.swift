//
//  LLMServiceProtocolTokenizeMockTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct LLMServiceProtocolTokenizeMockTests {

    @Test func emptyTextReturnsEmpty() async throws {
        let mock = MockLLMService()
        let pieces = try await mock.tokenize("")
        #expect(pieces.isEmpty)
    }

    @Test func exactMatchIsReturned() async throws {
        let mock = MockLLMService()
        mock.stubbedTokens["我爱"] = [
            TokenPiece(id: 7, text: "我"),
            TokenPiece(id: 8, text: "爱")
        ]
        let pieces = try await mock.tokenize("我爱")
        #expect(pieces.count == 2)
        #expect(pieces[0] == TokenPiece(id: 7, text: "我"))
        #expect(pieces[1] == TokenPiece(id: 8, text: "爱"))
    }

    @Test func emptyKeyIsCatchAll() async throws {
        let mock = MockLLMService()
        mock.stubbedTokens[""] = [TokenPiece(id: 99, text: "anything")]
        let pieces = try await mock.tokenize("some random text")
        #expect(pieces == [TokenPiece(id: 99, text: "anything")])
    }

    @Test func unknownTextWithoutCatchAllReturnsEmpty() async throws {
        let mock = MockLLMService()
        let pieces = try await mock.tokenize("anything")
        #expect(pieces.isEmpty)
    }

    @Test func errorBubblesUp() async {
        struct StubError: Error {}
        let mock = MockLLMService()
        mock.tokenizeError = StubError()
        await #expect(throws: StubError.self) {
            _ = try await mock.tokenize("anything")
        }
    }
}

//
//  MockLLMServiceTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

private typealias Message = llm_visualizer.Message

@MainActor
struct MockLLMServiceTests {

    @Test func loadModelReturnsContainer() async throws {
        let mock = MockLLMService()
        let container = try await mock.loadModel()
        #expect(mock.loadModelCallCount == 1)
        // ModelContainer is opaque; just verify it exists
        _ = container
    }

    @Test func generateEmitsChunksFromStub() async throws {
        let mock = MockLLMService()
        mock.stubbedChunks = ["Hello", " world", "!"]
        let container = try await mock.loadModel()
        let messages: [Message] = [.user("hi")]

        let stream = try await mock.generate(messages: messages, model: container)
        var collected: [String] = []
        for await gen in stream {
            if case .chunk(let s) = gen { collected.append(s) }
        }
        #expect(collected == ["Hello", " world", "!"])
    }
}

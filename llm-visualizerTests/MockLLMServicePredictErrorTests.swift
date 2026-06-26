//
//  MockLLMServicePredictErrorTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct MockLLMServicePredictErrorTests {

    @Test func predictNextTokensThrowsWhenPredictErrorSet() async {
        let mock = MockLLMService()
        mock.predictNextTokensError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "forced predict failure"]
        )
        do {
            _ = try await mock.predictNextTokens(prompt: "x", topK: 4)
            Issue.record("Expected throw")
        } catch {
            #expect((error as NSError).localizedDescription == "forced predict failure")
        }
    }

    @Test func predictNextTokensReturnsStubWhenNoError() async throws {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "a", probability: 0.5)
        ]
        let result = try await mock.predictNextTokens(prompt: "x", topK: 4)
        #expect(result.count == 1)
        #expect(result.first?.text == "a")
    }
}
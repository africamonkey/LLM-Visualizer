//
//  LLMServicePredictTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

@MainActor
struct LLMServicePredictTests {

    @Test func mockReturnsStubbedCandidates() async throws {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.32),
            TokenCandidate(id: 2, text: "不", probability: 0.18),
            TokenCandidate(id: 3, text: "的", probability: 0.14),
        ]
        let result = try await mock.predictNextTokens(prompt: "今天天气真", topK: 3)
        #expect(result.count == 3)
        #expect(result[0].text == "好")
        #expect(result[0].probability == 0.32)
    }

    @Test func mockDefaultsToEmptyWhenUnset() async throws {
        let mock = MockLLMService()
        let result = try await mock.predictNextTokens(prompt: "x", topK: 4)
        #expect(result.isEmpty)
    }

    @Test func mockTruncatesToTopK() async throws {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = (1...10).map { i in
            TokenCandidate(id: i, text: "t\(i)", probability: Double(11 - i) / 55.0)
        }
        let result = try await mock.predictNextTokens(prompt: "x", topK: 3)
        #expect(result.count == 3)
        #expect(result[0].text == "t1")
    }
}
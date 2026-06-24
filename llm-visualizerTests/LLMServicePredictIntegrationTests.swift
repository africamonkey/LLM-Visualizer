//
//  LLMServicePredictIntegrationTests.swift
//
//  These tests require the real model and a Metal-capable simulator
//  (or device). Skipped if XCTestConfigurationFilePath is set.

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct LLMServicePredictIntegrationTests {

    private func skipIfTestBundle() -> Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @Test func realPredictReturnsTopK() async throws {
        guard !skipIfTestBundle() else { return }
        let service = LLMService()
        let candidates = try await service.predictNextTokens(
            prompt: "今天天气真", topK: 4)
        #expect(candidates.count == 4)
        #expect(candidates[0].probability >= candidates[1].probability)
        // Sanity: probabilities sum is near 1.0 (after softmax).
        let sum = candidates.reduce(0.0) { $0 + $1.probability }
        #expect(sum > 0.0)
    }

    @Test func highlyPredictablePromptHitsHighTop1() async throws {
        guard !skipIfTestBundle() else { return }
        let service = LLMService()
        let candidates = try await service.predictNextTokens(
            prompt: "2 + 2 =", topK: 1)
        #expect(candidates.count == 1)
        // Loose expectation — model is small but should be very confident.
        #expect(candidates[0].probability > 0.5)
    }
}
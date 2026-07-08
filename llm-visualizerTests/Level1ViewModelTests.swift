//
//  Level1ViewModelTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

private typealias Message = llm_visualizer.Message

@MainActor
struct Level1ViewModelTests {

    private func vm(stubbed: [TokenCandidate]) -> Level1ViewModel {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = stubbed
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        return Level1ViewModel(service: mock, progressStore: store)
    }

    @Test func initialState() {
        let v = vm(stubbed: [])
        #expect(v.prompt.isEmpty)
        #expect(v.topCandidates.isEmpty)
        #expect(v.bestSoFar == 0.0)
        #expect(v.submitCount == 0)
        #expect(v.state == .playing)
    }

    @Test func submitEmptyPromptIsNoOp() async {
        let v = vm(stubbed: [])
        v.prompt = "   "
        await v.submit()
        #expect(v.topCandidates.isEmpty)
        #expect(v.submitCount == 0)
    }

    @Test func submitUpdatesCandidatesAndBestSoFar() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "好", probability: 0.40),
            TokenCandidate(id: 2, text: "不", probability: 0.20),
        ])
        v.prompt = "今天天气真"
        await v.submit()
        #expect(v.topCandidates.count == 2)
        #expect(v.bestSoFar == 0.40)
        #expect(v.submitCount == 1)
    }

    @Test func bestSoFarIsMax() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.10),
            TokenCandidate(id: 2, text: "x", probability: 0.55),
            TokenCandidate(id: 3, text: "x", probability: 0.30),
        ])
        v.prompt = "a"; await v.submit()
        v.prompt = "b"; await v.submit()
        v.prompt = "c"; await v.submit()
        #expect(v.bestSoFar == 0.55)
    }

    @Test func top1Over90PercentPassesLevel() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "国", probability: 0.95),
        ])
        v.prompt = "中华人民共和"
        await v.submit()
        #expect(v.state == .passed)
    }

    @Test func passIsStickyAfterLowerSubmission() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "国", probability: 0.95),
            TokenCandidate(id: 2, text: "a", probability: 0.20),
        ])
        v.prompt = "x"; await v.submit()
        #expect(v.state == .passed)
        v.prompt = "y"; await v.submit()
        #expect(v.state == .passed)
    }

    @Test func belowThresholdStaysPlaying() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.30),
        ])
        v.prompt = "x"
        await v.submit()
        #expect(v.state == .playing)
    }
}
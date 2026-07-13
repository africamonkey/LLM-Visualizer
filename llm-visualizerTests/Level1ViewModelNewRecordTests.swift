//
//  Level1ViewModelNewRecordTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level1ViewModelNewRecordTests {

    private func vm(stubbed: [TokenCandidate]) -> Level1ViewModel {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = stubbed
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        return Level1ViewModel(service: mock, progressStore: store)
    }

    @Test func newRecordSetWhenBeatingBest() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.95),
        ])
        v.prompt = "test"
        await v.submit()
        #expect(v.isNewRecord == true)
    }

    @Test func dismissCelebrationClearsNewRecord() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.95),
        ])
        v.prompt = "test"
        await v.submit()
        #expect(v.isNewRecord == true)
        v.dismissCelebration()
        #expect(v.isNewRecord == false)
    }

    @Test func notNewRecordWhenBelowBest() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "x", probability: 0.50),
        ]
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.setBestProbability(1, 0.99)
        let v = Level1ViewModel(service: mock, progressStore: store)
        v.prompt = "test"
        await v.submit()
        #expect(v.isNewRecord == false)
    }

    @Test func newRecordClearedOnNextSubmitEvenIfNotPassing() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "x", probability: 0.95),
        ]
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let v = Level1ViewModel(service: mock, progressStore: store)
        v.prompt = "first"
        await v.submit()
        #expect(v.isNewRecord == true)
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 2, text: "y", probability: 0.30),
        ]
        v.prompt = "second"
        await v.submit()
        #expect(v.isNewRecord == false)
    }
}
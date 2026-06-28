//
//  OnboardingViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct OnboardingViewModelTests {

    private let example = OnboardingExample(
        prompt: "今天天气真",
        candidates: [
            TokenCandidate(id: 1, text: "好", probability: 0.65)
        ]
    )

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
        return ProgressStore(defaults: defaults)
    }

    private func makeVM(store: ProgressStore? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            example: example,
            progressStore: store ?? freshStore()
        )
    }

    @Test func initStoresExample() {
        let vm = makeVM()
        #expect(vm.example.prompt == "今天天气真")
        #expect(vm.example.candidates.count == 1)
    }

    @Test func acceptChallengeWritesPersistenceAndInvokesCallback() {
        let store = freshStore()
        let vm = makeVM(store: store)
        var callbackFired = false
        vm.acceptChallenge { callbackFired = true }
        #expect(callbackFired == true)
        #expect(store.hasSeenOnboarding == true)
    }
}
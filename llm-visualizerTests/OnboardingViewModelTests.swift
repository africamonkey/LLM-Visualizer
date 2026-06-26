//
//  OnboardingViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct OnboardingViewModelTests {

    private let firstExample = OnboardingExample(
        prompt: "Today's weather is",
        candidates: [
            TokenCandidate(id: 1, text: "sunny", probability: 0.85)
        ]
    )
    private let secondExample = OnboardingExample(
        prompt: "I love eating",
        candidates: [
            TokenCandidate(id: 2, text: "pizza", probability: 0.35)
        ]
    )

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
        return ProgressStore(defaults: defaults)
    }

    private func makeVM(store: ProgressStore? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            firstExample: firstExample,
            secondExample: secondExample,
            progressStore: store ?? freshStore()
        )
    }

    @Test func initStoresExamples() {
        let vm = makeVM()
        #expect(vm.firstExample.prompt == "Today's weather is")
        #expect(vm.firstExample.candidates.count == 1)
        #expect(vm.secondExample.prompt == "I love eating")
        #expect(vm.secondExample.candidates.count == 1)
    }

    @Test func initialStepIsFirstExample() {
        let vm = makeVM()
        #expect(vm.step == .firstExample)
    }
}

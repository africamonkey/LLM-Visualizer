//
//  OnboardingViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct OnboardingViewModelTests {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
    }

    private func makeVM() -> OnboardingViewModel {
        ProgressStore.shared  // keep linker happy
        return OnboardingViewModel(service: MockLLMService())
    }

    @Test func initialPhaseIsOpening() {
        let vm = makeVM()
        #expect(vm.phase == .opening)
    }

    @Test func bestSoFarStartsAtZero() {
        let vm = makeVM()
        #expect(vm.bestSoFar == 0.0)
    }

    @Test func recordPlayBumpsCount() {
        let vm = makeVM()
        vm.transitionToFreePlay()
        vm.recordPlay(top1Probability: 0.32)
        #expect(vm.phase == .freePlay(playsSoFar: 1))
        #expect(vm.bestSoFar == 0.32)
    }

    @Test func recordPlayUpdatesBestSoFar() {
        let vm = makeVM()
        vm.transitionToFreePlay()
        vm.recordPlay(top1Probability: 0.10)
        vm.recordPlay(top1Probability: 0.55)
        vm.recordPlay(top1Probability: 0.30)
        #expect(vm.bestSoFar == 0.55)
    }

    @Test func showChallengeManuallyJumpsToIntro() {
        let vm = makeVM()
        vm.transitionToFreePlay()
        vm.showChallengeManually()
        #expect(vm.phase == .challengeIntro)
    }

    @Test func acceptChallengeWritesPersistenceAndInvokesCallback() {
        let defaults = freshDefaults()
        let store = ProgressStore(defaults: defaults)
        _ = store  // ensure init
        let vm = OnboardingViewModel(
            service: MockLLMService(),
            progressStore: ProgressStore(defaults: defaults)
        )
        var callbackFired = false
        vm.acceptChallenge { callbackFired = true }
        #expect(callbackFired == true)
        #expect(ProgressStore(defaults: defaults).hasSeenOnboarding == true)
    }
}

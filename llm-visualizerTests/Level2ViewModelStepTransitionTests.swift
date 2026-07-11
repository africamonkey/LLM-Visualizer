//
//  Level2ViewModelStepTransitionTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level2ViewModelStepTransitionTests {

    private func freshVM() -> Level2ViewModel {
        let mock = MockLLMService()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
        return Level2ViewModel(service: mock, progressStore: store)
    }

    @Test func initialStepIsHook() {
        let vm = freshVM()
        #expect(vm.step == .hook)
    }

    @Test func acknowledgeHookAdvancesToDemo() {
        let vm = freshVM()
        vm.acknowledgeHook()
        #expect(vm.step == .demo)
    }

    @Test func acknowledgeDemoAdvancesToChallengeIntro() {
        let vm = freshVM()
        vm.acknowledgeDemo()
        #expect(vm.step == .challengeIntro)
    }

    @Test func acknowledgeChallengeAdvancesToPlaying() {
        let vm = freshVM()
        vm.acknowledgeChallenge()
        #expect(vm.step == .playing)
    }

    @Test func acknowledgePassedReturnsToPlaying() {
        let vm = freshVM()
        vm.step = .passed
        vm.acknowledgePassed()
        #expect(vm.step == .playing)
    }

    @Test func bestCharCountRestoredFromStore() {
        let store = ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
        store.setBestCharacterCount(2, 7)
        let mock = MockLLMService()
        let vm = Level2ViewModel(service: mock, progressStore: store)
        #expect(vm.bestCharCount == 7)
    }
}

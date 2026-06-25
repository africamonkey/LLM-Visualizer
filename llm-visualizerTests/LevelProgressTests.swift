//
//  LevelProgressTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
struct LevelProgressTests {

    private func freshStore() -> ProgressStore {
        let suiteName = "llmviz.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return ProgressStore(defaults: defaults)
    }

    @Test func hasSeenOnboardingDefaultsFalse() {
        let store = freshStore()
        #expect(store.hasSeenOnboarding == false)
    }

    @Test func hasSeenOnboardingRoundTrip() {
        let store = freshStore()
        store.hasSeenOnboarding = true
        #expect(store.hasSeenOnboarding == true)
    }

    @Test func levelCompletionDefaultsFalse() {
        let store = freshStore()
        #expect(store.isComplete(1) == false)
    }

    @Test func levelCompletionRoundTrip() {
        let store = freshStore()
        store.setComplete(1, true)
        #expect(store.isComplete(1) == true)
    }

    @Test func setCompleteFalseRemoves() {
        let store = freshStore()
        store.setComplete(1, true)
        store.setComplete(1, false)
        #expect(store.isComplete(1) == false)
    }

    @Test func multipleLevelsAreIndependent() {
        let store = freshStore()
        store.setComplete(1, true)
        store.setComplete(7, true)
        #expect(store.isComplete(1))
        #expect(store.isComplete(7))
        #expect(!store.isComplete(2))
    }
}

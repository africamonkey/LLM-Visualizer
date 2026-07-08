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

    @Test func bestProbabilityDefaultsZero() {
        let store = freshStore()
        #expect(store.bestProbability(1) == 0.0)
    }

    @Test func bestProbabilityRoundTrip() {
        let store = freshStore()
        store.setBestProbability(1, 0.42)
        #expect(store.bestProbability(1) == 0.42)
    }

    @Test func bestProbabilityIsMonotonic() {
        let store = freshStore()
        store.setBestProbability(1, 0.30)
        store.setBestProbability(1, 0.50)
        store.setBestProbability(1, 0.40)
        #expect(store.bestProbability(1) == 0.50)
    }

    @Test func bestProbabilityIsIndependentPerLevel() {
        let store = freshStore()
        store.setBestProbability(1, 0.80)
        store.setBestProbability(2, 0.95)
        #expect(store.bestProbability(1) == 0.80)
        #expect(store.bestProbability(2) == 0.95)
    }

    @Test func bestProbabilityClampsToValidRange() {
        let store = freshStore()
        store.setBestProbability(1, 1.5)
        #expect(store.bestProbability(1) == 1.0)
        store.setBestProbability(1, -0.3)
        #expect(store.bestProbability(1) == 1.0)
    }
}

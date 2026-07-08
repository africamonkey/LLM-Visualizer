//
//  ProgressStoreResetTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct ProgressStoreResetTests {

    @Test func resetClearsAllKeys() {
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.hasSeenOnboarding = true
        store.setComplete(1, true)
        store.setBestProbability(1, 0.9)
        store.reset()
        #expect(store.hasSeenOnboarding == false)
        #expect(store.isComplete(1) == false)
        #expect(store.bestProbability(1) == 0.0)
    }

    @Test func resetOnEmptyStoreIsNoOp() {
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.reset()
        #expect(store.hasSeenOnboarding == false)
    }
}

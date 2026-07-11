//
//  ProgressStoreCharacterCountTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
struct ProgressStoreCharacterCountTests {

    private func freshStore() -> ProgressStore {
        let suiteName = "llmviz.test.\(UUID().uuidString)"
        return ProgressStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    @Test func defaultsToZero() {
        let store = freshStore()
        #expect(store.bestCharacterCount(2) == 0)
    }

    @Test func roundTrip() {
        let store = freshStore()
        store.setBestCharacterCount(2, 7)
        #expect(store.bestCharacterCount(2) == 7)
    }

    @Test func monotonicMax() {
        let store = freshStore()
        store.setBestCharacterCount(2, 3)
        store.setBestCharacterCount(2, 5)
        store.setBestCharacterCount(2, 4)
        #expect(store.bestCharacterCount(2) == 5)
    }

    @Test func independentPerLevel() {
        let store = freshStore()
        store.setBestCharacterCount(2, 7)
        store.setBestCharacterCount(3, 2)
        #expect(store.bestCharacterCount(2) == 7)
        #expect(store.bestCharacterCount(3) == 2)
        #expect(store.bestCharacterCount(99) == 0)
    }

    @Test func neverGoesNegative() {
        let store = freshStore()
        store.setBestCharacterCount(2, -3)
        // Negative values are clamped to 0 — the metric is a count.
        #expect(store.bestCharacterCount(2) == 0)
    }
}

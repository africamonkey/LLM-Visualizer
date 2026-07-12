//
//  Level2RegistryTests.swift
//

import Foundation
import SwiftUI
import Testing
@testable import llm_visualizer

@MainActor
struct Level2RegistryTests {

    private func makeSession() -> Level2Session {
        let mock = MockLLMService()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
        return Level2Session(
            viewModel: Level2ViewModel(service: mock, progressStore: store)
        )
    }

    @Test func levelTwoIsInRegistry() {
        let names = LevelRegistry.all.map { String(describing: $0.type) }
        #expect(names.contains("Level2Session"))
    }

    @Test func levelTwoIsNotCompleteByDefault() {
        let s = makeSession()
        #expect(s.isComplete == false)
    }

    @Test func levelTwoHasIdTwo() {
        let s = makeSession()
        #expect(s.id == 2)
    }

    @Test func levelTwoContentViewRenders() {
        let _ = makeSession().makeContentView()
    }

    @Test func defaultSessionStartsAtHook() {
        let s = makeSession()
        #expect(s.viewModel.step == .hook)
    }
}
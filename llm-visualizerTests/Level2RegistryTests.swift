//
//  Level2RegistryTests.swift
//

import Foundation
import SwiftUI
import Testing
@testable import llm_visualizer

@MainActor
struct Level2RegistryTests {

    private func makeSession(skipIntro: Bool = false) -> Level2Session {
        let mock = MockLLMService()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
        return Level2Session(
            viewModel: Level2ViewModel(
                service: mock,
                progressStore: store,
                skipIntro: skipIntro
            )
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

    /// B4: `skipIntro: true` makes the session start at .playing instead of .hook.
    @Test func skipIntroLandsAtPlaying() {
        let s = makeSession(skipIntro: true)
        #expect(s.viewModel.step == .playing)
    }

    @Test func defaultSessionStartsAtHook() {
        let s = makeSession()
        #expect(s.viewModel.step == .hook)
    }
}
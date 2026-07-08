//
//  Level2RegistryTests.swift
//

import Foundation
import SwiftUI
import Testing
@testable import llm_visualizer

@MainActor
struct Level2RegistryTests {

    @Test func levelTwoIsInRegistry() {
        let names = LevelRegistry.all.map { String(describing: $0) }
        #expect(names.contains("Level2Session"))
    }

    @Test func levelTwoIsNotCompleteByDefault() {
        let s = Level2Session()
        #expect(s.isComplete == false)
    }

    @Test func levelTwoHasIdTwo() {
        let s = Level2Session()
        #expect(s.id == 2)
    }

    @Test func levelTwoContentViewRenders() {
        let _ = Level2Session().makeContentView()
    }
}

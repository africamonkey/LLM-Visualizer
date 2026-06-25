//
//  LevelRegistryTests.swift
//

import Foundation
import SwiftUI
import Testing
@testable import llm_visualizer

private final class StubSession: LevelSession {
    var evaluateCallCount = 0
    override init(id: Int, title: String, subtitle: String, goalDescription: String) {
        super.init(id: id, title: title, subtitle: subtitle, goalDescription: goalDescription)
    }
    override func makeContentView() -> AnyView {
        AnyView(Text("stub"))
    }
    override func evaluate() {
        evaluateCallCount += 1
        isComplete = true
    }
}

@Suite(.serialized)
struct LevelRegistryTests {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
    }

    @MainActor
    @Test func isCompleteDefaultsFalse() {
        ProgressStore.shared.setComplete(1, false)
        let store = ProgressStore(defaults: freshDefaults())
        let s = StubSession(id: 1, title: "t", subtitle: "s", goalDescription: "g")
        _ = store  // silence unused warning if any
        #expect(s.isComplete == false)
    }

    @MainActor
    @Test func evaluateMarksComplete() {
        let store = ProgressStore(defaults: freshDefaults())
        _ = store
        let s = StubSession(id: 1, title: "t", subtitle: "s", goalDescription: "g")
        #expect(s.evaluateCallCount == 0)
        s.evaluate()
        #expect(s.evaluateCallCount == 1)
        #expect(s.isComplete == true)
    }

    @Test func registryContainsAtLeastOne() {
        #expect(LevelRegistry.all.count >= 1)
    }
}

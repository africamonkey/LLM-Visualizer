//
//  AppShellViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct AppShellViewModelTests {

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
        return ProgressStore(defaults: defaults)
    }

    @Test func initialStateIsLoading() {
        let appVM = AppShellViewModel(
            service: MockLLMService(),
            progressStore: freshStore()
        )
        #expect(appVM.state == .loading)
        #expect(appVM.example1 == nil)
        #expect(appVM.example2 == nil)
    }
}
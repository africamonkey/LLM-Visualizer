//
//  Level2ViewModelErrorPathTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level2ViewModelErrorPathTests {

    private struct StubError: Error {}

    @Test func tokenizeErrorSetsBanner() async {
        let mock = MockLLMService()
        mock.tokenizeError = StubError()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.rawText = "anything"
        await vm.waitForPendingTokenize()
        #expect(vm.errorBanner != nil)
        #expect(vm.tokens.isEmpty)
        #expect(vm.step == .playing)
    }

    @Test func recoveryAfterError() async {
        let mock = MockLLMService()
        mock.tokenizeError = StubError()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.rawText = "bad"
        await vm.waitForPendingTokenize()
        #expect(vm.errorBanner != nil)

        // Clear the error and stub a valid response.
        mock.tokenizeError = nil
        mock.stubbedTokens = ["ok": [TokenPiece(id: 100, text: "ok")]]
        vm.errorBanner = nil // simulate user dismissal or auto-clear
        vm.rawText = "ok"
        await vm.waitForPendingTokenize()
        #expect(vm.errorBanner == nil)
        #expect(vm.tokens == [TokenPiece(id: 100, text: "ok")])
    }
}

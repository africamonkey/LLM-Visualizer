//
//  Level2ViewModelPassDetectionTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level2ViewModelPassDetectionTests {

    private func freshStore() -> ProgressStore {
        ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
    }

    private func playingVM(stubbed: [String: [TokenPiece]]) -> Level2ViewModel {
        let mock = MockLLMService()
        mock.stubbedTokens = stubbed
        let vm = Level2ViewModel(service: mock, progressStore: freshStore())
        vm.step = .playing
        return vm
    }

    @Test func singleTokenPassesAndPersists() async {
        let vm = playingVM(stubbed: ["我": [TokenPiece(id: 1, text: "我")]])
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        #expect(vm.step == .passed)
        #expect(vm.bestCharCount == 1)
        #expect(vm.attemptCount == 0)
    }

    @Test func emptyInputDoesNotPass() async {
        let vm = playingVM(stubbed: [:])
        vm.rawText = ""
        await vm.waitForPendingTokenize()
        #expect(vm.step == .playing)
        #expect(vm.bestCharCount == 0)
    }

    @Test func whitespaceOnlyDoesNotPass() async {
        let vm = playingVM(stubbed: ["   ": [TokenPiece(id: 5, text: " ")]])
        vm.rawText = "   "
        await vm.waitForPendingTokenize()
        // 1 token, but trimmed grapheme count is 0 → pass should NOT fire.
        #expect(vm.step == .playing)
    }

    @Test func multiTokenDoesNotPassAndIncrementsAttempts() async {
        let vm = playingVM(stubbed: [
            "我爱": [TokenPiece(id: 1, text: "我"), TokenPiece(id: 2, text: "爱")]
        ])
        vm.rawText = "我爱"
        await vm.waitForPendingTokenize()
        #expect(vm.step == .playing)
        #expect(vm.attemptCount == 1)
    }

    @Test func bestCharCountPersistsAcrossLongerPass() async {
        let store = freshStore()
        // Seed prior best of 3 chars.
        store.setBestCharacterCount(2, 3)

        let mock = MockLLMService()
        // First attempt: 2-token stub → no pass.
        mock.stubbedTokens = ["爱我": [
            TokenPiece(id: 1, text: "爱"),
            TokenPiece(id: 2, text: "我"),
        ]]

        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.rawText = "爱我"
        await vm.waitForPendingTokenize()
        #expect(vm.step == .playing)
        #expect(vm.attemptCount == 1)

        // Second attempt: single-token packed 4-char word → pass.
        mock.stubbedTokens = ["五星红旗": [
            TokenPiece(id: 50, text: "五星红旗"),
        ]]
        vm.rawText = "五星红旗"
        await vm.waitForPendingTokenize()
        #expect(vm.step == .passed)
        // bestCharCount now 4 (was 3 from store).
        #expect(vm.bestCharCount == 4)
        #expect(vm.attemptCount == 0)
    }

    @Test func lowerScoreAfterPassDoesNotLower() async {
        let store = freshStore()
        let mock = MockLLMService()
        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.attemptCount = 9 // simulate near-hint-tier state

        // Pass at 4 chars.
        mock.stubbedTokens = ["五星红旗": [TokenPiece(id: 1, text: "五星红旗")]]
        vm.rawText = "五星红旗"
        await vm.waitForPendingTokenize()
        let highScore = vm.bestCharCount
        #expect(vm.step == .passed)
        #expect(highScore == 4)

        // Continue grinding; pass again at 1 char.
        vm.acknowledgePassed()
        mock.stubbedTokens = ["我": [TokenPiece(id: 2, text: "我")]]
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        // bestCharCount must not decrease.
        #expect(vm.bestCharCount == highScore)
    }
}

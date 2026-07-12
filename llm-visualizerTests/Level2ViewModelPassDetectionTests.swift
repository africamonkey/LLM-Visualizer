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

    /// B1: pass detection is gated behind an explicit `submit()` call. Typing
    /// in the field updates tokens visually (via `isPassing`) but does NOT
    /// flip step or persist best. Only submit does.
    @Test func typingAloneDoesNotPass() async {
        let store = freshStore()
        let mock = MockLLMService()
        mock.stubbedTokens = ["我": [TokenPiece(id: 1, text: "我")]]
        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        // No submit yet — still playing.
        #expect(vm.step == .playing)
        #expect(vm.bestCharCount == 0)
        #expect(store.bestCharacterCount(2) == 0)
        // isPassing updates in real time (visual feedback), independent of submit.
        #expect(vm.isPassing == true)
    }

    @Test func submitOnSingleTokenPassesAndPersists() async {
        let store = freshStore()
        let mock = MockLLMService()
        mock.stubbedTokens = ["我": [TokenPiece(id: 1, text: "我")]]
        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .passed)
        #expect(vm.bestCharCount == 1)
        #expect(store.bestCharacterCount(2) == 1)
        #expect(vm.attemptCount == 0)
        #expect(vm.isNewRecord == true)
    }

    @Test func emptyInputDoesNotPass() async {
        let vm = playingVM(stubbed: [:])
        vm.rawText = "x"
        await vm.waitForPendingTokenize()
        vm.rawText = ""
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .playing)
        #expect(vm.bestCharCount == 0)
        #expect(vm.isPassing == false)
    }

    @Test func whitespaceOnlyDoesNotPass() async {
        let vm = playingVM(stubbed: ["   ": [TokenPiece(id: 5, text: " ")]])
        vm.rawText = "   "
        await vm.waitForPendingTokenize()
        vm.submit()
        // 1 token, but trimmed grapheme count is 0 → pass should NOT fire.
        #expect(vm.step == .playing)
        #expect(vm.isPassing == false)
    }

    /// B3: attemptCount only increments on submit, not on every keystroke.
    @Test func submitOnMultiTokenIncrementsAttemptsOnce() async {
        let vm = playingVM(stubbed: [
            "我爱": [TokenPiece(id: 1, text: "我"), TokenPiece(id: 2, text: "爱")]
        ])
        vm.rawText = "我爱"
        await vm.waitForPendingTokenize()
        #expect(vm.attemptCount == 0) // no submit yet
        vm.submit()
        #expect(vm.step == .playing)
        #expect(vm.attemptCount == 1)
        #expect(vm.isPassing == false)
    }

    @Test func bestCharCountPersistsAcrossLongerPass() async {
        let store = freshStore()
        store.setBestCharacterCount(2, 3)

        let mock = MockLLMService()
        mock.stubbedTokens = ["爱我": [
            TokenPiece(id: 1, text: "爱"),
            TokenPiece(id: 2, text: "我"),
        ]]

        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        vm.rawText = "爱我"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .playing)
        #expect(vm.attemptCount == 1)
        #expect(vm.isPassing == false)

        // Second attempt: single-token packed 4-char word → pass.
        mock.stubbedTokens = ["五星红旗": [
            TokenPiece(id: 50, text: "五星红旗"),
        ]]
        vm.rawText = "五星红旗"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .passed)
        #expect(vm.bestCharCount == 4)
        #expect(vm.attemptCount == 0)
        #expect(vm.isPassing == true)
        #expect(vm.isNewRecord == true)
    }

    /// B11: acknowledgePassed clears rawText/tokens/attemptCount/hintTier so
    /// the next playing round starts fresh.
    @Test func acknowledgePassedResetsRound() async {
        let mock = MockLLMService()
        mock.stubbedTokens = ["我": [TokenPiece(id: 1, text: "我")]]
        let vm = Level2ViewModel(service: mock, progressStore: freshStore())
        vm.step = .playing
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .passed)
        vm.acknowledgePassed()
        #expect(vm.step == .playing)
        #expect(vm.rawText == "")
        #expect(vm.tokens.isEmpty)
        #expect(vm.isPassing == false)
        #expect(vm.attemptCount == 0)
        #expect(vm.isNewRecord == false)
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
        vm.submit()
        let highScore = vm.bestCharCount
        #expect(vm.step == .passed)
        #expect(highScore == 4)
        #expect(vm.isNewRecord == true)

        // Continue grinding; pass again at 1 char.
        vm.acknowledgePassed()
        mock.stubbedTokens = ["我": [TokenPiece(id: 2, text: "我")]]
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        vm.submit()
        // bestCharCount must not decrease.
        #expect(vm.bestCharCount == highScore)
        // 4 < 4 → not a new record this time.
        #expect(vm.isNewRecord == false)
    }

    /// B6: isNewRecord is true only when this pass set a NEW high water mark.
    @Test func isNewRecordOnlyWhenBeatingBest() async {
        let store = freshStore()
        store.setBestCharacterCount(2, 5)
        let mock = MockLLMService()
        let vm = Level2ViewModel(service: mock, progressStore: store)
        vm.step = .playing
        mock.stubbedTokens = ["我": [TokenPiece(id: 1, text: "我")]]
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.bestCharCount == 5) // unchanged
        #expect(vm.isNewRecord == false)
    }

    /// B2: submit() during demo / challengeIntro / passed is a no-op.
    /// The user can type freely during the demo phase without accidentally
    /// triggering a pass transition.
    @Test func submitIsNoOpOutsidePlaying() async {
        let store = freshStore()
        let mock = MockLLMService()
        mock.stubbedTokens = ["我": [TokenPiece(id: 1, text: "我")]]
        let vm = Level2ViewModel(service: mock, progressStore: store)

        // demo: type and submit; nothing happens.
        vm.step = .demo
        vm.rawText = "我"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .demo)
        #expect(vm.bestCharCount == 0)

        // challengeIntro: same.
        vm.step = .challengeIntro
        vm.submit()
        #expect(vm.step == .challengeIntro)
        #expect(vm.bestCharCount == 0)
    }

    /// PassedView uses `earnedStars(for: charCount)` to show stars for THIS
    /// attempt's char count, not the all-time best. So a user who passed
    /// at 7 chars and then at 3 chars should see 1 star (3 chars → 1 star)
    /// on the second celebration, not 3 stars (the all-time best).
    @Test func earnedStarsIsForThisAttempt() {
        let vm = Level2ViewModel(service: MockLLMService(), progressStore: freshStore())
        #expect(vm.earnedStars(for: 0) == 0)
        #expect(vm.earnedStars(for: 2) == 0)
        #expect(vm.earnedStars(for: 3) == 1)
        #expect(vm.earnedStars(for: 4) == 1)
        #expect(vm.earnedStars(for: 5) == 2)
        #expect(vm.earnedStars(for: 6) == 2)
        #expect(vm.earnedStars(for: 7) == 3)
        #expect(vm.earnedStars(for: 50) == 3)
    }
}
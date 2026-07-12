//
//  Level2ViewModelHintTierTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level2ViewModelHintTierTests {

    private func freshStore() -> ProgressStore {
        ProgressStore(defaults: UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!)
    }

    private func playingVM() -> Level2ViewModel {
        let mock = MockLLMService()
        mock.stubbedTokens[""] = [TokenPiece(id: 1, text: "x"), TokenPiece(id: 2, text: "y")]
        let vm = Level2ViewModel(service: mock, progressStore: freshStore())
        vm.step = .playing
        return vm
    }

    /// B3: attemptCount only increments on explicit submit. Each `failOnce`
    /// now sets text + submits, which is one "failed attempt".
    private func failOnce(vm: Level2ViewModel, _ text: String) async {
        vm.rawText = text
        await vm.waitForPendingTokenize()
        vm.submit()
    }

    @Test func noHintBelowThreshold() async {
        let vm = playingVM()
        for i in 0..<4 { await failOnce(vm: vm, "ai\(i)") }
        #expect(vm.attemptCount == 4)
        #expect(vm.hintTier == .none)
    }

    @Test func directionHintAtThreshold() async {
        let vm = playingVM()
        for i in 0..<5 { await failOnce(vm: vm, "ai\(i)") }
        #expect(vm.attemptCount == 5)
        #expect(vm.hintTier == .direction)
    }

    @Test func exampleHintAtSecondThreshold() async {
        let vm = playingVM()
        for i in 0..<10 { await failOnce(vm: vm, "ai\(i)") }
        #expect(vm.attemptCount == 10)
        #expect(vm.hintTier == .example)
    }

    /// B2: hint tier escalates only via submit() (not via rawText change).
    @Test func typingAloneDoesNotEscalateHint() async {
        let vm = playingVM()
        for i in 0..<10 {
            vm.rawText = "ai\(i)"
            await vm.waitForPendingTokenize()
        }
        // No submit was called. attemptCount should still be 0.
        #expect(vm.attemptCount == 0)
        #expect(vm.hintTier == .none)
    }

    @Test func passResetsHintState() async {
        let vm = playingVM()
        for i in 0..<10 { await failOnce(vm: vm, "ai\(i)") }
        #expect(vm.hintTier == .example)

        // Configure a single-token stub and pass.
        if let mock = vm.service as? MockLLMService {
            mock.stubbedTokens = ["ok": [TokenPiece(id: 100, text: "ok")]]
        }
        vm.rawText = "ok"
        await vm.waitForPendingTokenize()
        vm.submit()
        #expect(vm.step == .passed)
        #expect(vm.attemptCount == 0)
        #expect(vm.hintTier == .none)
    }

    @Test func applyHint2ExampleSetsRawTextWithoutAutoSubmit() async {
        let store = freshStore()
        let mock = MockLLMService()
        mock.stubbedTokens["我"] = [TokenPiece(id: 1, text: "我")]
        let vm = Level2ViewModel(
            service: mock,
            progressStore: store,
            hint2ExampleText: "我"
        )
        vm.step = .playing
        vm.applyHint2Example()
        await vm.waitForPendingTokenize()
        #expect(vm.rawText == "我")
        #expect(vm.tokens == [TokenPiece(id: 1, text: "我")])
        // applyHint2Example autofills rawText but does NOT auto-submit. User
        // can still edit before tapping Submit.
        #expect(vm.step == .playing)
        #expect(vm.attemptCount == 0)
    }
}
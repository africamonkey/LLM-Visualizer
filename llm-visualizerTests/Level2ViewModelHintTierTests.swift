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

    private func failOnce(vm: Level2ViewModel, _ text: String) async {
        // Multi-token stub forces a non-pass path.
        vm.rawText = text
        await vm.waitForPendingTokenize()
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

    @Test func passResetsHintState() async {
        let vm = playingVM()
        for i in 0..<10 { await failOnce(vm: vm, "ai\(i)") }
        #expect(vm.hintTier == .example)

        // Configure a single-token stub and pass.
        // `service` is non-`private` on the VM (see Task 6 scaffold),
        // so the test can mutate the mock directly.
        if let mock = vm.service as? MockLLMService {
            mock.stubbedTokens = ["ok": [TokenPiece(id: 100, text: "ok")]]
        }
        vm.rawText = "ok"
        await vm.waitForPendingTokenize()
        #expect(vm.step == .passed)
        #expect(vm.attemptCount == 0)
        #expect(vm.hintTier == .none)
    }

    @Test func applyHint2ExampleSetsRawText() async {
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
    }
}

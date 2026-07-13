//
//  Level1ViewModelTokensTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level1ViewModelTokensTests {

    private func vm() -> (Level1ViewModel, MockLLMService) {
        let mock = MockLLMService()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        return (Level1ViewModel(service: mock, progressStore: store), mock)
    }

    @Test func promptChangeTriggersTokenize() async {
        let (v, mock) = vm()
        mock.stubbedTokens["hi"] = [TokenPiece(id: 1, text: "hi")]
        v.prompt = "hi"
        await v.waitForPendingTokenize()
        #expect(v.tokens.map(\.text) == ["hi"])
    }

    @Test func rapidPromptChangesCancelPrior() async {
        let (v, mock) = vm()
        mock.stubbedTokens["a"] = [TokenPiece(id: 1, text: "a")]
        mock.stubbedTokens["ab"] = [TokenPiece(id: 2, text: "ab")]
        v.prompt = "a"
        v.prompt = "ab"
        await v.waitForPendingTokenize()
        #expect(v.tokens.map(\.text) == ["ab"])
    }

    @Test func emptyPromptProducesEmptyTokens() async {
        let (v, mock) = vm()
        mock.stubbedTokens["hi"] = [TokenPiece(id: 1, text: "hi")]
        v.prompt = "hi"
        await v.waitForPendingTokenize()
        #expect(v.tokens.count == 1)
        v.prompt = ""
        await v.waitForPendingTokenize()
        #expect(v.tokens.isEmpty)
    }

    @Test func tokenizeErrorShowsBanner() async {
        let (v, mock) = vm()
        mock.tokenizeError = NSError(domain: "test", code: 1)
        v.prompt = "x"
        await v.waitForPendingTokenize()
        #expect(v.errorBanner != nil)
    }

    @Test func promptEqualsOldValueDoesNotRetokenize() async {
        let (v, mock) = vm()
        mock.stubbedTokens["hi"] = [TokenPiece(id: 1, text: "hi")]
        v.prompt = "hi"
        await v.waitForPendingTokenize()
        let countAfterFirst = v.tokens.count
        v.prompt = "hi"
        await v.waitForPendingTokenize()
        #expect(v.tokens.count == countAfterFirst)
    }
}
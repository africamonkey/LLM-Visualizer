//
//  ChatViewModelGenerateTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

// Disambiguate from MLXLMCommon.Message
private typealias Message = llm_visualizer.Message

@MainActor
struct ChatViewModelGenerateTests {

    @Test func generateWithEmptyPromptIsNoOp() async throws {
        let mock = MockLLMService()
        let vm = ChatViewModel(service: mock)
        vm.prompt = "   "
        await vm.generate()
        #expect(vm.messages.count == 1) // only system message
        #expect(vm.messages.first?.role == .system)
    }

    @Test func generateAppendsUserAndAssistantPlaceholder() async throws {
        let mock = MockLLMService()
        let vm = ChatViewModel(service: mock)
        vm.prompt = "hello"
        await vm.generate()
        #expect(vm.messages.count == 3) // system + user + assistant placeholder
        #expect(vm.messages[1].role == .user)
        #expect(vm.messages[1].content == "hello")
        #expect(vm.messages[2].role == .assistant)
        #expect(vm.messages[2].content.isEmpty) // placeholder is empty
    }

    @Test func generateStreamsChunksIntoLastAssistantMessage() async throws {
        let mock = MockLLMService()
        mock.stubbedChunks = ["Hello", " world"]
        let vm = ChatViewModel(service: mock)
        vm.prompt = "hi"
        await vm.generate()
        let last = vm.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.content == "Hello world")
        #expect(vm.prompt.isEmpty)
    }
}

//
//  ChatViewModelResetTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

// Disambiguate from MLXLMCommon.Message
private typealias Message = llm_visualizer.Message

@MainActor
struct ChatViewModelResetTests {

    @Test func resetKeepsSystemMessageClearsOthers() async throws {
        let mock = MockLLMService()
        let vm = ChatViewModel(service: mock)
        vm.messages.append(.user("hello"))
        vm.messages.append(.assistant("hi"))
        vm.prompt = "draft"
        vm.tokensPerSecond = 12.3

        vm.reset()

        #expect(vm.messages.count == 1)
        #expect(vm.messages.first?.role == .system)
        #expect(vm.prompt.isEmpty)
        #expect(vm.tokensPerSecond == 0)
    }
}

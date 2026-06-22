//
//  ChatViewModelCancelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

// Disambiguate from MLXLMCommon.Message
private typealias Message = llm_visualizer.Message

@MainActor
struct ChatViewModelCancelTests {

    @Test func cancelAppendsCancelledMarker() async throws {
        let mock = MockLLMService()
        // Hold the stream open so cancellation has time to take effect
        // before the stream ends naturally.
        mock.stubbedChunks = ["partial"]
        mock.stubbedFinish = false
        let vm = ChatViewModel(service: mock)
        vm.prompt = "hi"

        // Start generation but don't await — we cancel it.
        let task = Task { await vm.generate() }
        // give the task a moment to start
        try? await Task.sleep(nanoseconds: 50_000_000)
        vm.cancel()
        await task.value

        #expect(vm.messages.last?.content.contains("[Cancelled]") == true)
        #expect(vm.isGenerating == false)
    }
}

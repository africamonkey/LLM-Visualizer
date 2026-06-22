//
//  LLMService.swift
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN
import Tokenizers

protocol LLMServiceProtocol: Sendable {
    func loadModel() async throws -> ModelContainer
    func generate(messages: [Message], model: ModelContainer) async throws -> AsyncStream<Generation>
}

final class LLMService: LLMServiceProtocol, @unchecked Sendable {
    private var cached: ModelContainer?

    init() {}

    func loadModel() async throws -> ModelContainer {
        if let cached { return cached }
        Memory.cacheLimit = 20 * 1024 * 1024
        let container = try await LLMModelFactory.shared.loadContainer(configuration: ModelConfig.configuration)
        cached = container
        return container
    }

    func generate(messages: [Message], model: ModelContainer) async throws -> AsyncStream<Generation> {
        try await model.perform { context in
            let chatMessages = messages.map { message -> Chat.Message in
                let role: Chat.Message.Role
                switch message.role {
                case .user: role = .user
                case .assistant: role = .assistant
                case .system: role = .system
                }
                return Chat.Message(role: role, content: message.content)
            }
            let userInput = UserInput(chat: chatMessages)
            let lmInput = try await context.processor.prepare(input: userInput)
            return try MLXLMCommon.generate(
                input: lmInput,
                parameters: ModelConfig.parameters,
                context: context
            )
        }
    }
}

private final class StubLanguageModel: Module, LanguageModel {
    nonisolated override init() {
        super.init()
    }
    func prepare(_ input: LMInput, cache: [KVCache], windowSize: Int?) throws -> PrepareResult {
        fatalError("StubLanguageModel is never invoked")
    }
    func callAsFunction(_ input: LMInput.Text, cache: [KVCache]?, state: LMOutput.State?) -> LMOutput {
        fatalError("StubLanguageModel is never invoked")
    }
    func newCache(parameters: GenerateParameters?) -> [KVCache] {
        fatalError("StubLanguageModel is never invoked")
    }
    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        weights
    }
    func sanitize(weights: [String: MLXArray], metadata: [String: String]) -> [String: MLXArray] {
        weights
    }
}

private final class StubTokenizer: Tokenizer, @unchecked Sendable {
    let bosToken: String? = nil
    let bosTokenId: Int? = nil
    let eosToken: String? = nil
    let eosTokenId: Int? = nil
    let unknownToken: String? = nil
    let unknownTokenId: Int? = nil

    func tokenize(text: String) -> [String] { fatalError("StubTokenizer is never invoked") }
    func encode(text: String) -> [Int] { fatalError("StubTokenizer is never invoked") }
    func encode(text: String, addSpecialTokens: Bool) -> [Int] { fatalError("StubTokenizer is never invoked") }
    func decode(tokens: [Int], skipSpecialTokens: Bool) -> String { fatalError("StubTokenizer is never invoked") }
    func convertTokenToId(_ token: String) -> Int? { fatalError("StubTokenizer is never invoked") }
    func convertIdToToken(_ id: Int) -> String? { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message]) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message], tools: [Tokenizers.ToolSpec]?) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message], tools: [Tokenizers.ToolSpec]?, additionalContext: [String: any Sendable]?) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message], chatTemplate: Tokenizers.ChatTemplateArgument) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message], chatTemplate: String) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message], chatTemplate: Tokenizers.ChatTemplateArgument?, addGenerationPrompt: Bool, truncation: Bool, maxLength: Int?, tools: [Tokenizers.ToolSpec]?) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
    func applyChatTemplate(messages: [Tokenizers.Message], chatTemplate: Tokenizers.ChatTemplateArgument?, addGenerationPrompt: Bool, truncation: Bool, maxLength: Int?, tools: [Tokenizers.ToolSpec]?, additionalContext: [String: any Sendable]?) throws -> [Int] { fatalError("StubTokenizer is never invoked") }
}

final class MockLLMService: LLMServiceProtocol, @unchecked Sendable {

    static var sharedContainer: ModelContainer?

    private(set) var loadModelCallCount = 0
    var stubbedChunks: [String] = []
    var stubbedFinish: Bool = true
    var stubbedInfo: GenerateCompletionInfo?
    var loadModelError: Error?

    init() {}

    func loadModel() async throws -> ModelContainer {
        loadModelCallCount += 1
        if let error = loadModelError { throw error }
        if let container = MockLLMService.sharedContainer {
            return container
        }
        let container = makeStubContainer()
        MockLLMService.sharedContainer = container
        return container
    }

    func generate(messages: [Message], model: ModelContainer) async throws -> AsyncStream<Generation> {
        AsyncStream { continuation in
            for chunk in stubbedChunks {
                continuation.yield(.chunk(chunk))
            }
            if let info = stubbedInfo {
                continuation.yield(.info(info))
            }
            if stubbedFinish {
                continuation.finish()
            }
            // When stubbedFinish is false the stream stays open until
            // the consumer's Task is cancelled. This is how the
            // cancellation test observes a real cancel.
        }
    }

    private func makeStubContainer() -> ModelContainer {
        let context = ModelContext(
            configuration: ModelConfig.configuration,
            model: StubLanguageModel(),
            processor: StandInUserInputProcessor(),
            tokenizer: StubTokenizer()
        )
        return ModelContainer(context: context)
    }
}

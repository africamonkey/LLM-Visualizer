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
    @MainActor
    func loadModel() async throws -> ModelContainer
    @MainActor
    func generate(
        messages: [Message],
        model: ModelContainer,
        onToken: @escaping @Sendable (Int) -> Void
    ) async throws -> AsyncStream<Generation>
    @MainActor
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate]
    @MainActor
    func tokenize(_ text: String) async throws -> [TokenPiece]
}

final class LLMService: LLMServiceProtocol, @unchecked Sendable {
    private var cached: ModelContainer?

    init() {}

    @MainActor
    func loadModel() async throws -> ModelContainer {
        if let cached { return cached }
        Memory.cacheLimit = 20 * 1024 * 1024
        let container = try await LLMModelFactory.shared.loadContainer(configuration: ModelConfig.configuration)
        cached = container
        return container
    }

    @MainActor
    func generate(
        messages: [Message],
        model: ModelContainer,
        onToken: @escaping @Sendable (Int) -> Void
    ) async throws -> AsyncStream<Generation> {
        try await model.perform { context in
            let chatMessages: [Chat.Message] = {
                var working = messages
                if let last = working.last, last.role == .assistant, last.content.isEmpty {
                    working.removeLast()
                }
                return working.map { message in
                    let role: Chat.Message.Role
                    switch message.role {
                    case .user: role = .user
                    case .assistant: role = .assistant
                    case .system: role = .system
                    }
                    return Chat.Message(role: role, content: message.content)
                }
            }()
            let userInput = UserInput(chat: chatMessages)
            let lmInput = try await context.processor.prepare(input: userInput)
            let tokenStream = try MLXLMCommon.generateTokens(
                input: lmInput,
                parameters: ModelConfig.parameters,
                context: context
            )
            let tokenizer = context.tokenizer

            return AsyncStream<Generation> { continuation in
                let task = Task {
                    var detokenizer = NaiveStreamingDetokenizer(tokenizer: tokenizer)
                    for await tg in tokenStream {
                        switch tg {
                        case .token(let t):
                            onToken(t)
                            detokenizer.append(token: t)
                            if let chunk = detokenizer.next() {
                                continuation.yield(.chunk(chunk))
                            }
                        case .info(let i):
                            continuation.yield(.info(i))
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    @MainActor
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate] {
        let container = try await ensureContainer()
        return try await container.perform { context in
            // Completion mode. We deliberately bypass the chat template (UserInput +
            // processor.prepare) and feed the user's raw text straight to the model.
            //
            // The chat path wraps the input as `user\n{prompt}\n\nassistant\n[...]` so
            // the model behaves as an assistant replying to a user message — its top-1
            // is the start of the assistant's reply ("是啊", "确实", etc.), not a
            // continuation of the user's text. For the visualizer we want the
            // opposite: the user provides a sentence fragment and we show the model's
            // distribution over what would naturally come next in that fragment
            // (e.g. "今天天气真" → "好" / "差" / "不" / ...).
            //
            // Qwen3's base stage is next-token prediction; the chat template is a
            // post-training wrapper. Without it, the model falls back to base-model
            // completion behavior, which is exactly what we want here. The chat
            // app uses chat mode (see `generate(messages:)`) for free conversation.
            //
            // `tokenizer.encode(text:)` returns `[Int]` token IDs. The model expects
            // a 2D `(batch=1, seq_len)` input; the `[.newAxis]` subscript adds the
            // batch dimension (matches what `TokenIterator.step` does internally for
            // generation).
            let promptTokens = try context.tokenizer.encode(text: prompt)
            let text = MLXArray(promptTokens)[.newAxis]
            // `LanguageModel` has two `callAsFunction` overloads — one taking
            // `LMInput.Text` (returns `LMOutput`) and one taking `MLXArray`
            // (returns `MLXArray` of logits). Drop the `state:` argument so the
            // compiler picks the MLXArray overload, which gives us the logits
            // directly from the model's forward pass.
            let logits = context.model(text, cache: nil)
            // logits shape: [batch=1, seq, vocab]. Take last position.
            let lastLogits = logits[0, logits.dim(1) - 1, 0...].asType(.float32)
            let probs = softmax(lastLogits, axis: -1)
            let vocab = probs.dim(0)
            let k = min(max(topK, 1), vocab)
            // Sort -probs ascending = sort probs descending (highest first).
            // argSort returns uint32 indices; takeAlong gathers values in the same order.
            let sortedIndicesDesc = argSort(-probs, axis: -1)
            let topKIndices = sortedIndicesDesc[..<k]
            let topKValues = takeAlong(probs, topKIndices, axis: -1)
            let tokenizer = context.tokenizer
            var out: [TokenCandidate] = []
            out.reserveCapacity(k)
            for i in 0..<k {
                let tokenId = Int(topKIndices[i].item(Int32.self))
                let prob = Double(topKValues[i].item(Float32.self))
                let text = tokenizer.decode(tokens: [tokenId], skipSpecialTokens: false)
                out.append(TokenCandidate(id: tokenId, text: text, probability: prob))
            }
            return out
        }
    }

    @MainActor
    func tokenize(_ text: String) async throws -> [TokenPiece] {
        if text.isEmpty { return [] }
        let container = try await ensureContainer()
        return try await container.perform { context in
            let ids = try context.tokenizer.encode(text: text)
            let tokenizer = context.tokenizer
            return ids.map { id in
                TokenPiece(
                    id: id,
                    text: tokenizer.decode(tokens: [id], skipSpecialTokens: false)
                )
            }
        }
    }

    private func ensureContainer() async throws -> ModelContainer {
        if let cached { return cached }
        return try await loadModel()
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
    var stubbedTokenDelayMillis: Int = 0
    var stubbedFinish: Bool = true
    var stubbedInfo: GenerateCompletionInfo?
    var stubbedPredictTopK: [TokenCandidate] = []
    var loadModelError: Error?
    var predictNextTokensError: Error?
    var stubbedTokens: [String: [TokenPiece]] = [:]
    var tokenizeError: Error?

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

    func generate(
        messages: [Message],
        model: ModelContainer,
        onToken: @escaping @Sendable (Int) -> Void
    ) async throws -> AsyncStream<Generation> {
        AsyncStream { continuation in
            let task = Task {
                for (i, chunk) in stubbedChunks.enumerated() {
                    if Task.isCancelled { break }
                    onToken(i)
                    continuation.yield(.chunk(chunk))
                    if stubbedTokenDelayMillis > 0 {
                        try? await Task.sleep(for: .milliseconds(stubbedTokenDelayMillis))
                    }
                }
                if let info = stubbedInfo {
                    continuation.yield(.info(info))
                }
                if stubbedFinish && !Task.isCancelled {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate] {
        if let error = predictNextTokensError { throw error }
        let clamped = max(0, topK)
        return Array(stubbedPredictTopK.prefix(clamped))
    }

    @MainActor
    func tokenize(_ text: String) async throws -> [TokenPiece] {
        if let error = tokenizeError { throw error }
        if text.isEmpty { return [] }
        return stubbedTokens[text] ?? stubbedTokens[""] ?? []
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

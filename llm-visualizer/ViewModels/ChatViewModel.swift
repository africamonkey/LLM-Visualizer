//
//  ChatViewModel.swift
//

import Foundation
import MLXLMCommon
import os

@MainActor
@Observable
final class ChatViewModel {

    enum ModelState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private let service: LLMServiceProtocol
    private var modelContainer: ModelContainer?
    private var generateTask: Task<Void, Never>?
    private var generationStartTime: Date?

    var messages: [Message] = [.system("You are a helpful assistant.")]
    var prompt: String = ""
    var modelState: ModelState = .idle
    var tokensPerSecond: Double = 0
    var isGenerating: Bool = false
    var errorBanner: String?

    init(service: LLMServiceProtocol) {
        self.service = service
    }

    func bootstrap() async {
        modelState = .loading
        do {
            let container = try await service.loadModel()
            modelContainer = container
            modelState = .loaded
        } catch {
            modelState = .error(error.localizedDescription)
        }
    }

    func generate() async {
        if generateTask != nil { generateTask?.cancel() }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        messages.append(.user(prompt))
        messages.append(.assistant(""))
        let lastIndex = messages.count - 1
        prompt = ""
        isGenerating = true

        let model: ModelContainer
        do {
            if let existing = modelContainer {
                model = existing
            } else {
                let loaded = try await service.loadModel()
                modelContainer = loaded
                modelState = .loaded
                model = loaded
            }
        } catch {
            messages[lastIndex].content = "[Error: \(error.localizedDescription)]"
            errorBanner = error.localizedDescription
            isGenerating = false
            return
        }

        let counter = TokenCounter()
        counter.start()
        generationStartTime = Date()

        generateTask = Task { @MainActor in
            do {
                let stream = try await service.generate(
                    messages: messages,
                    model: model,
                    onToken: { [counter, weak self] _ in
                        let count = counter.increment()
                        Task { @MainActor [weak self] in
                            self?.applyTokenCount(count)
                        }
                    }
                )
                for await gen in stream {
                    if Task.isCancelled { break }
                    switch gen {
                    case .chunk(let s):
                        messages[lastIndex].content += s
                    case .info(let i):
                        tokensPerSecond = i.tokensPerSecond
                    case .toolCall:
                        break
                    }
                }
                if Task.isCancelled {
                    messages[lastIndex].content += "\n[Cancelled]"
                }
            } catch is CancellationError {
                messages[lastIndex].content += "\n[Cancelled]"
            } catch {
                messages[lastIndex].content += "\n[Error: \(error.localizedDescription)]"
                let message = error.localizedDescription
                errorBanner = message
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    if errorBanner == message { errorBanner = nil }
                }
            }
            applyTokenCount(counter.currentCount())
            isGenerating = false
            generateTask = nil
        }
        await generateTask?.value
    }

    private func applyTokenCount(_ count: Int) {
        guard let start = generationStartTime, count > 0 else { return }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return }
        tokensPerSecond = Double(count) / elapsed
    }

    func cancel() {
        generateTask?.cancel()
    }

    func reset() {
        generateTask?.cancel()
        messages = [.system("You are a helpful assistant.")]
        prompt = ""
        tokensPerSecond = 0
        errorBanner = nil
    }
}

private final class TokenCounter: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<Int>(initialState: 0)

    func start() {
        lock.withLock { $0 = 0 }
    }

    func increment() -> Int {
        lock.withLock { current in
            current += 1
            return current
        }
    }

    func currentCount() -> Int {
        lock.withLock { $0 }
    }
}

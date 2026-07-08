//
//  Level1ViewModel.swift
//

import Foundation
import MLXLMCommon
import os

@MainActor
@Observable
final class Level1ViewModel {

    enum State: Equatable { case playing, passed }

    static let passThreshold: Double = 0.90

    private let service: LLMServiceProtocol
    private let progressStore: ProgressStore
    private var modelContainer: ModelContainer?
    private var autoClearTask: Task<Void, Never>?

    var prompt: String = ""
    var topCandidates: [TokenCandidate] = []
    var bestSoFar: Double = 0.0
    var submitCount: Int = 0
    var state: State = .playing
    var isLoading: Bool = false
    var errorBanner: String?

    init(service: LLMServiceProtocol, progressStore: ProgressStore = .shared) {
        self.service = service
        self.progressStore = progressStore
        self.bestSoFar = progressStore.bestProbability(1)
    }

    func bootstrap() async {
        do {
            let container = try await service.loadModel()
            modelContainer = container
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func submit() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let container = try await ensureContainer()
            let candidates = try await service.predictNextTokens(
                prompt: trimmed, topK: 4)
            topCandidates = candidates
            submitCount += 1
            let maxProb = candidates.map(\.probability).max() ?? 0
            if maxProb > bestSoFar {
                bestSoFar = maxProb
                progressStore.setBestProbability(1, maxProb)
            }
            if let top1 = candidates.first,
               top1.probability > Self.passThreshold,
               state != .passed {
                state = .passed
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func continueAfterPass() {
        // Celebration dismissed; state stays .passed so the ✓ badge
        // remains in the header and the goal indicator doesn't re-suggest.
    }

    private func ensureContainer() async throws -> ModelContainer {
        if let m = modelContainer { return m }
        let m = try await service.loadModel()
        modelContainer = m
        return m
    }

    private func showError(_ message: String) {
        errorBanner = message
        autoClearTask?.cancel()
        autoClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if self.errorBanner == message { self.errorBanner = nil }
        }
    }
}
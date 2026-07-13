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
    private var autoClearTask: Task<Void, Never>?

    var prompt: String = "" {
        didSet {
            guard oldValue != prompt else { return }
            onPromptChanged()
        }
    }
    var topCandidates: [TokenCandidate] = []
    var bestSoFar: Double = 0.0
    var submitCount: Int = 0
    var state: State = .playing
    var isLoading: Bool = false
    var tokens: [TokenPiece] = []
    private(set) var tokenizeTask: Task<Void, Never>?
    var errorBanner: String?

    init(service: LLMServiceProtocol, progressStore: ProgressStore = .shared) {
        self.service = service
        self.progressStore = progressStore
        self.bestSoFar = progressStore.bestProbability(1)
    }

    func submit() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
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
               top1.probability > Self.passThreshold {
                state = .passed
            }
        } catch {
            showError(LevelError.humanize(error))
        }
    }

    /// Reset the transient `.passed` state back to `.playing` so the next
    /// pass-eligible submission can re-fire the celebration. The persistent
    /// "level complete" flag lives on `LevelSession.isComplete` and is
    /// unaffected.
    func dismissCelebration() {
        if state == .passed { state = .playing }
    }

    /// Wait for the in-flight tokenize task to complete. Tests use this to
    /// await real-time tokenization deterministically. No-op when no task.
    func waitForPendingTokenize() async {
        await tokenizeTask?.value
    }

    /// Real-time tokenize pipeline: every keystroke cancels any prior task
    /// and launches a fresh one. Mirrors `Level2ViewModel.onRawTextChanged`.
    /// Errors surface via `errorBanner` (3s auto-clear, same as submit errors).
    private func onPromptChanged() {
        tokenizeTask?.cancel()
        let text = prompt
        tokenizeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let pieces = try await self.service.tokenize(text)
                guard !Task.isCancelled else { return }
                self.tokens = pieces
            } catch {
                guard !Task.isCancelled else { return }
                self.showError(LevelError.humanize(error))
            }
        }
    }

    /// Whether the *current* top-1 token exceeds the pass threshold.
    /// Independent of `state` — used to color the probability bars and
    /// determine whether the current submission is a winner.
    var currentTop1IsPass: Bool {
        (topCandidates.first?.probability ?? 0) > Self.passThreshold
    }

    /// Narrator sentiment: in playing state shows the current top-1's confidence.
    /// After passing, prefixes the line with "You passed" so the user knows
    /// their new submission doesn't un-do the achievement.
    var currentSentiment: NarratorLineView.Sentiment {
        let top1 = topCandidates.first?.probability ?? 0
        let base = NarratorLineView.sentiment(for: top1)
        return state == .passed ? .passed(current: base) : base
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
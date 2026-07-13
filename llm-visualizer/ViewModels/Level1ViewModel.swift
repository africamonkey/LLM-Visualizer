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

    var prompt: String = ""
    var topCandidates: [TokenCandidate] = []
    var bestSoFar: Double = 0.0
    /// True when the most recent `submit()` set a new `bestSoFar` record.
    /// Cleared on `dismissCelebration()`. Drives the "NEW BEST" badge on
    /// `PassCelebrationView`.
    private(set) var isNewRecord: Bool = false
    var submitCount: Int = 0
    var state: State = .playing
    var isLoading: Bool = false
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
                isNewRecord = true
                bestSoFar = maxProb
                progressStore.setBestProbability(1, maxProb)
            } else {
                isNewRecord = false
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
        isNewRecord = false
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
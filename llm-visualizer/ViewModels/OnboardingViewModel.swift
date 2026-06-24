//
//  OnboardingViewModel.swift
//

import Foundation
import MLXLMCommon
import os

@MainActor
@Observable
final class OnboardingViewModel {

    enum ModelState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    var phase: OnboardingPhase = .opening
    var modelState: ModelState = .idle
    private(set) var bestSoFar: Double = 0.0

    private let service: LLMServiceProtocol
    private let progressStore: ProgressStore
    private var modelContainer: ModelContainer?
    private var autoShowTask: Task<Void, Never>?

    init(
        service: LLMServiceProtocol,
        progressStore: ProgressStore = .shared
    ) {
        self.service = service
        self.progressStore = progressStore
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

    /// Called by the view when the user advances past `OpeningView`.
    func transitionToFreePlay() {
        phase = .freePlay(playsSoFar: 0)
    }

    /// Called by the view after each user submit during free-play.
    /// Updates best-so-far, bumps the plays count. Does NOT
    /// auto-advance to challenge intro — the view decides based on
    /// its own logic (auto after delay, or via showChallengeManually).
    func recordPlay(top1Probability: Double) {
        bestSoFar = max(bestSoFar, top1Probability)
        let next = currentPlays + 1
        phase = .freePlay(playsSoFar: next)
    }

    /// User explicitly tapped the "我准备好了" chip. Cancels any
    /// pending auto-show task and jumps to challenge intro.
    func showChallengeManually() {
        autoShowTask?.cancel()
        autoShowTask = nil
        phase = .challengeIntro
    }

    /// User accepted the challenge. Writes persistence and invokes
    /// the closure passed by the App root.
    func acceptChallenge(onComplete: @escaping () -> Void) {
        autoShowTask?.cancel()
        autoShowTask = nil
        progressStore.hasSeenOnboarding = true
        onComplete()
    }

    /// Schedule the auto-show: after the 2nd play + a 3-second delay,
    /// jump to challenge intro unless the user already moved past it.
    func scheduleAutoShowIfSecondPlay() {
        guard currentPlays == 2 else { return }
        autoShowTask?.cancel()
        autoShowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if case .freePlay(let n) = self.phase, n >= 2 {
                self.phase = .challengeIntro
            }
        }
    }

    private var currentPlays: Int {
        if case .freePlay(let n) = phase { return n }
        return 0
    }
}

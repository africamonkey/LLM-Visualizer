//
//  OnboardingViewModel.swift
//

import Foundation

@MainActor
@Observable
final class OnboardingViewModel {

    enum Step { case example, challengeIntro }
    var step: Step = .example

    let example: OnboardingExample

    private let progressStore: ProgressStore

    init(
        example: OnboardingExample,
        progressStore: ProgressStore = .shared
    ) {
        self.example = example
        self.progressStore = progressStore
    }

    func goNext() {
        switch step {
        case .example:        step = .challengeIntro
        case .challengeIntro: break
        }
    }

    func acceptChallenge(onComplete: @escaping () -> Void) {
        progressStore.hasSeenOnboarding = true
        onComplete()
    }
}

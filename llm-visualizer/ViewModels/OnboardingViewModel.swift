//
//  OnboardingViewModel.swift
//

import Foundation

@MainActor
@Observable
final class OnboardingViewModel {

    let example: OnboardingExample

    private let progressStore: ProgressStore

    init(
        example: OnboardingExample,
        progressStore: ProgressStore = .shared
    ) {
        self.example = example
        self.progressStore = progressStore
    }

    func acceptChallenge(onComplete: @escaping () -> Void) {
        progressStore.hasSeenOnboarding = true
        onComplete()
    }
}
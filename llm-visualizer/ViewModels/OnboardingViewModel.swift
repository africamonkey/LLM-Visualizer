//
//  OnboardingViewModel.swift
//

import Foundation

@MainActor
@Observable
final class OnboardingViewModel {

    enum Step { case firstExample, secondExample, challengeIntro }
    var step: Step = .firstExample

    let firstExample: OnboardingExample
    let secondExample: OnboardingExample

    private let progressStore: ProgressStore

    init(
        firstExample: OnboardingExample,
        secondExample: OnboardingExample,
        progressStore: ProgressStore = .shared
    ) {
        self.firstExample = firstExample
        self.secondExample = secondExample
        self.progressStore = progressStore
    }
}

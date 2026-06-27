//
//  AppShellViewModel.swift
//

import Foundation

@MainActor
@Observable
final class AppShellViewModel {

    enum State: Equatable {
        case loading
        case failed(String)
        case ready(hasSeenOnboarding: Bool)
    }

    var state: State = .loading
    let service: LLMServiceProtocol
    private let progressStore: ProgressStore
    private let onboardingPrompt: String

    private(set) var example: OnboardingExample?

    init(
        service: LLMServiceProtocol,
        progressStore: ProgressStore = .shared,
        onboardingPrompt: String
    ) {
        self.service = service
        self.progressStore = progressStore
        self.onboardingPrompt = onboardingPrompt
    }

    func bootstrap() async {
        state = .loading
        do {
            try await service.loadModel()
            let candidates = try await service.predictNextTokens(
                prompt: onboardingPrompt,
                topK: 4
            )
            self.example = OnboardingExample(
                prompt: onboardingPrompt,
                candidates: candidates
            )
            state = .ready(hasSeenOnboarding: progressStore.hasSeenOnboarding)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        await bootstrap()
    }

    func markOnboardingComplete() {
        if case .ready(let hasSeen) = state, !hasSeen {
            state = .ready(hasSeenOnboarding: true)
        }
    }
}
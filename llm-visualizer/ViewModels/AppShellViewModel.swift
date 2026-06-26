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

    private(set) var example1: OnboardingExample?
    private(set) var example2: OnboardingExample?

    init(
        service: LLMServiceProtocol,
        progressStore: ProgressStore = .shared
    ) {
        self.service = service
        self.progressStore = progressStore
    }

    static let onboardingPrompts: [String] = [
        "Today's weather is",
        "I love eating",
    ]

    func bootstrap() async {
        state = .loading
        do {
            try await service.loadModel()
            let p1 = Self.onboardingPrompts[0]
            let p2 = Self.onboardingPrompts[1]
            let c1 = try await service.predictNextTokens(prompt: p1, topK: 4)
            let c2 = try await service.predictNextTokens(prompt: p2, topK: 4)
            self.example1 = OnboardingExample(prompt: p1, candidates: c1)
            self.example2 = OnboardingExample(prompt: p2, candidates: c2)
            state = .ready(hasSeenOnboarding: progressStore.hasSeenOnboarding)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
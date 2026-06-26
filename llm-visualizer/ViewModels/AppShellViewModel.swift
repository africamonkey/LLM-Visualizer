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
}
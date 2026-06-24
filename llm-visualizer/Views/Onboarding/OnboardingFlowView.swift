//
//  OnboardingFlowView.swift
//

import SwiftUI

struct OnboardingFlowView: View {

    @State var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @MainActor
    init(
        viewModel: OnboardingViewModel? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = viewModel ?? OnboardingViewModel(service: LLMService())
        self.onComplete = onComplete
    }

    private let openingPrompt = "今天天气真"

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .opening:
                openingScreen
            case .freePlay:
                FreePlayView(
                    viewModel: makeLevel1VM(),
                    playsSoFar: currentPlays,
                    onUserSubmitted: handleSubmit,
                    onTapReady: { viewModel.showChallengeManually() }
                )
            case .challengeIntro:
                FreePlayView(
                    viewModel: makeLevel1VM(),
                    playsSoFar: currentPlays,
                    onUserSubmitted: handleSubmit,
                    onTapReady: { viewModel.showChallengeManually() }
                )
                .allowsHitTesting(false)
                ChallengeIntroView(
                    bestSoFar: viewModel.bestSoFar,
                    onAccept: { viewModel.acceptChallenge(onComplete: onComplete) }
                )
            }
        }
        .task {
            // Skip model load during unit/UI tests — Metal doesn't init in simulator
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            await viewModel.bootstrap()
            let service = LLMService()
            do {
                openingCandidates = try await service.predictNextTokens(
                    prompt: openingPrompt, topK: 4)
            } catch {
                openingCandidates = []
            }
            openingLoading = false
        }
    }

    @State private var openingCandidates: [TokenCandidate] = []
    @State private var openingLoading: Bool = true

    private var openingScreen: some View {
        OpeningView(
            candidates: openingCandidates,
            isLoading: openingLoading,
            onTap: { viewModel.transitionToFreePlay() }
        )
    }

    private var currentPlays: Int {
        if case .freePlay(let n) = viewModel.phase { return n }
        return 0
    }

    @State private var freePlayVM: Level1ViewModel?

    private func makeLevel1VM() -> Level1ViewModel {
        if let freePlayVM { return freePlayVM }
        let vm = Level1ViewModel(service: LLMService())
        freePlayVM = vm
        return vm
    }

    private func handleSubmit() {
        guard let top1 = freePlayVM?.topCandidates.first else { return }
        viewModel.recordPlay(top1Probability: top1.probability)
        viewModel.scheduleAutoShowIfSecondPlay()
    }
}
//
//  AppRootView.swift
//

import SwiftUI

struct AppRootView: View {

    @State private var appVM = AppShellViewModel(
        service: LLMService(),
        onboardingPrompt: String(
            localized: "onboarding.prompt",
            defaultValue: "今天天气真"
        )
    )
    @State private var currentLevelIndex: Int = 0

    var body: some View {
        Group {
            switch appVM.state {
            case .loading, .failed:
                ModelLoadingView(
                    state: appVM.state,
                    onRetry: { Task { await appVM.retry() } }
                )
            case .ready(let hasSeenOnboarding):
                if hasSeenOnboarding {
                    LevelShellView(
                        currentSession: sessionForCurrentIndex(),
                        hasNextLevel: hasNextLevel(),
                        onAdvanceLevel: { jumpToLevel(currentLevelIndex + 1) },
                        onJumpToLevel: { jumpToLevel($0) },
                        onReset: {
                            appVM.reset()
                            currentLevelIndex = 0
                        }
                    )
                } else if let example = appVM.example {
                    OnboardingFlowView(
                        viewModel: OnboardingViewModel(example: example),
                        onComplete: {
                            appVM.markOnboardingComplete()
                        }
                    )
                } else {
                    EmptyView()
                }
            }
        }
        .task {
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            await appVM.bootstrap()
        }
    }

    // MARK: - Level navigation

    /// Construct the session for `currentLevelIndex`. Every level always
    /// starts from its own opening screen (hook → demo → challengeIntro);
    /// we don't skip intro on inter-level navigation, so users get the full
    /// educational walkthrough the first time they reach each level.
    private func sessionForCurrentIndex() -> LevelSession {
        let type = LevelRegistry.all[currentLevelIndex].type
        switch type {
        case let t as Level1Session.Type:
            return t.make(service: appVM.service)
        case let t as Level2Session.Type:
            return t.make(service: appVM.service)
        default:
            fatalError("Unknown level type: \(type)")
        }
    }

    private func hasNextLevel() -> Bool {
        currentLevelIndex + 1 < LevelRegistry.all.count
    }

    private func jumpToLevel(_ index: Int) {
        let clamped = max(0, min(index, LevelRegistry.all.count - 1))
        currentLevelIndex = clamped
    }
}
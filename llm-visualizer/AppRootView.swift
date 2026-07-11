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
                            // State flip to .ready(hasSeenOnboarding: false)
                            // re-routes us to the onboarding branch below on the
                            // next render. After reset, restart at level 0.
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
                    // Defensive: .ready(false) should always have examples.
                    // Render an empty view rather than crash.
                    EmptyView()
                }
            }
        }
        .task {
            // Skip model load during unit/UI tests — Metal doesn't init in simulator.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            await appVM.bootstrap()
        }
    }

    // MARK: - Level navigation

    /// Construct the session for `currentLevelIndex`. Factories live on each
    /// `LevelSession` subclass so AppRootView stays decoupled.
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
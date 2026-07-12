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
    /// True for one body evaluation cycle after the user navigates to a
    /// different level. Used to pass `skipIntro: true` to Level 2 when the
    /// user advances from Level 1 (B4).
    @State private var didJustAdvance: Bool = false

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
                            didJustAdvance = false
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

    /// Construct the session for `currentLevelIndex`. For Level 2 (and any
    /// future level with an intro flow), pass `skipIntro: true` if the user
    /// just advanced from a previous level — they shouldn't have to walk the
    /// hook/demo/challengeIntro again (B4).
    private func sessionForCurrentIndex() -> LevelSession {
        let type = LevelRegistry.all[currentLevelIndex].type
        let skipIntro = didJustAdvance && currentLevelIndex > 0
        didJustAdvance = false  // consume — applies for one body cycle only
        switch type {
        case let t as Level1Session.Type:
            return t.make(service: appVM.service)
        case let t as Level2Session.Type:
            return t.make(service: appVM.service, skipIntro: skipIntro)
        default:
            fatalError("Unknown level type: \(type)")
        }
    }

    private func hasNextLevel() -> Bool {
        currentLevelIndex + 1 < LevelRegistry.all.count
    }

    private func jumpToLevel(_ index: Int) {
        let clamped = max(0, min(index, LevelRegistry.all.count - 1))
        if clamped != currentLevelIndex {
            didJustAdvance = true
        }
        currentLevelIndex = clamped
    }
}
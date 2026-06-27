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
                    LevelShellView(currentSession: Level1Session(
                        viewModel: Level1ViewModel(service: appVM.service)
                    ))
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
            // Skip model load during unit/UI tests — Metal doesn't init in simulator
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            await appVM.bootstrap()
        }
    }
}

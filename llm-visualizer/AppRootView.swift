//
//  AppRootView.swift
//

import SwiftUI

struct AppRootView: View {

    @State private var showOnboarding: Bool = false
    @State private var initialized: Bool = false

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingFlowView(
                    viewModel: OnboardingViewModel(service: LLMService()),
                    onComplete: { showOnboarding = false }
                )
            } else {
                LevelShellView(currentSession: Level1Session(
                    viewModel: Level1ViewModel(service: LLMService())
                ))
            }
        }
        .task {
            if !initialized {
                initialized = true
                showOnboarding = !ProgressStore.shared.hasSeenOnboarding
            }
        }
    }
}
//
//  Level2FlowView.swift
//

import SwiftUI

struct Level2FlowView: View {

    @Bindable var viewModel: Level2ViewModel
    @State private var showLevel3Toast: Bool = false

    var body: some View {
        Group {
            switch viewModel.step {
            case .hook:
                HookView(onContinue: viewModel.acknowledgeHook)
            case .demo:
                DemoView(
                    viewModel: viewModel,
                    onContinue: viewModel.acknowledgeDemo
                )
            case .challengeIntro:
                ChallengeIntroView(onContinue: viewModel.acknowledgeChallenge)
            case .playing:
                PlayingView(viewModel: viewModel)
            case .passed:
                PassedView(
                    viewModel: viewModel,
                    onContinueGrinding: viewModel.acknowledgePassed,
                    onGoToLevel3: { showLevel3Toast = true }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.step)
        .overlay(alignment: .bottom) {
            if showLevel3Toast {
                Text(String(
                    localized: "level2.level3Toast",
                    defaultValue: "Level 3 coming soon"
                ))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.black.opacity(0.85))
                )
                .foregroundStyle(.white)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    showLevel3Toast = false
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLevel3Toast)
    }
}

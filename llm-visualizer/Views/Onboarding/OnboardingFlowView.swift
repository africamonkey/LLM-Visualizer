//
//  OnboardingFlowView.swift
//

import SwiftUI

struct OnboardingFlowView: View {

    @State var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    init(
        viewModel: OnboardingViewModel,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            card
            if viewModel.step != .challengeIntro {
                nextButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private var card: some View {
        switch viewModel.step {
        case .example:
            ExampleCardView(
                prompt: viewModel.example.prompt,
                candidates: viewModel.example.candidates,
                caption: String(
                    localized: "onboarding.example.caption",
                    defaultValue: "These 100 dots are what the model on this device really thought. Now you try — can you make it more sure?"
                )
            )
        case .challengeIntro:
            ChallengeIntroView(
                onAccept: { viewModel.acceptChallenge(onComplete: onComplete) }
            )
        }
    }

    private var nextButton: some View {
        Button {
            viewModel.goNext()
        } label: {
            Text(String(localized: "onboarding.next", defaultValue: "Next"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .padding(20)
    }
}

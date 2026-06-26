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
        case .firstExample:
            ExampleCardView(
                prompt: viewModel.firstExample.prompt,
                candidates: viewModel.firstExample.candidates,
                caption: String(
                    localized: "onboarding.example1.caption",
                    defaultValue: "These 100 dots are what the model on this device just predicted for that sentence."
                )
            )
        case .secondExample:
            ExampleCardView(
                prompt: viewModel.secondExample.prompt,
                candidates: viewModel.secondExample.candidates,
                caption: String(
                    localized: "onboarding.example2.caption",
                    defaultValue: "Same model, different sentence — and the dots spread out."
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

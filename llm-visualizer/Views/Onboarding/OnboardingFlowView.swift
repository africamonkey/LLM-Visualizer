//
//  OnboardingFlowView.swift
//

import SwiftUI

struct OnboardingFlowView: View {

    let viewModel: OnboardingViewModel
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
            ExampleCardView(
                prompt: viewModel.example.prompt,
                candidates: viewModel.example.candidates,
                caption: String(
                    localized: "onboarding.example.caption",
                    defaultValue: "The model's actual guess — these are the words it considered, each with its own probability. Now you try to find a sentence where one word clearly wins."
                )
            )
            tryItButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var tryItButton: some View {
        Button {
            viewModel.acceptChallenge(onComplete: onComplete)
        } label: {
            Text(String(localized: "onboarding.tryIt", defaultValue: "Let me try"))
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
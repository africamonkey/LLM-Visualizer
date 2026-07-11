//
//  ChallengeIntroView.swift
//

import SwiftUI

struct ChallengeIntroView: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 16) {
                Text(String(
                    localized: "level2.challengeIntro.body",
                    defaultValue: "If AI chops by blocks, what could make it fit everything into a single block? Find the longest content you can that still fits in one block. Below: left is your character count, right is AI's block count. Keep the block count at 1 and the character count as high as possible."
                ))
                .font(.body)
            }
            .padding(.horizontal, 24)
            Spacer()
            Button(action: onContinue) {
                Text(String(
                    localized: "level2.challengeIntro.cta",
                    defaultValue: "Start"
                ))
                .font(.body.weight(.semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
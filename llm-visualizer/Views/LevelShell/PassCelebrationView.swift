//
//  PassCelebrationView.swift
//

import SwiftUI

struct PassCelebrationView: View {

    let echoedPrompt: String?
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.accentColor.opacity(0.18), Color(.systemBackground)],
                center: .init(x: 0.5, y: 0.4),
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 80))
                Text("FIRST CLEAR")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Color.accentColor)
                Text(String(
                    localized: "You made AI guess right with its eyes closed",
                    defaultValue: "You made AI guess right with its eyes closed"
                ))
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                if let prompt = echoedPrompt, !prompt.isEmpty {
                    VStack(spacing: 4) {
                        Text(String(
                            localized: "celebration.yourSentence",
                            defaultValue: "Your sentence"
                        ))
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        Text(prompt)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 8)
                }
                Text(String(
                    localized: "When the context is clear enough, the model already knows what comes next.",
                    defaultValue: "When the context is clear enough, the model already knows what comes next."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: onContinue) {
                    Text(String(localized: "Try again", defaultValue: "Try again"))
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}

#Preview {
    PassCelebrationView(echoedPrompt: "中华人民共和", onContinue: {})
}
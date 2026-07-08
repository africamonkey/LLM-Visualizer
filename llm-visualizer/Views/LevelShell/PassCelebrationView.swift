//
//  PassCelebrationView.swift
//

import SwiftUI

struct PassCelebrationView: View {

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
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
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
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

#Preview {
    PassCelebrationView(onContinue: {})
}
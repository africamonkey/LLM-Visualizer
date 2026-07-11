//
//  PassCelebrationView.swift
//

import SwiftUI

struct PassCelebrationView: View {

    let echoedPrompt: String?
    let topCandidate: TokenCandidate?
    let onContinue: () -> Void
    /// Optional closure invoked when the user taps "Next level →".
    /// Pass `nil` to hide the button (e.g., on the last level).
    let onGoToNextLevel: (() -> Void)?

    private var passColor: Color { Color(red: 0.13, green: 0.77, blue: 0.37) }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 64))
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
                summaryCard
                Text(String(
                    localized: "When the context is clear enough, the model already knows what comes next.",
                    defaultValue: "When the context is clear enough, the model already knows what comes next."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                actionButtons
                    .padding(.top, 12)
            }
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: onContinue) {
                Text(String(localized: "Try again", defaultValue: "Try again"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if let onGoToNextLevel {
                Button(action: onGoToNextLevel) {
                    Text(String(
                        localized: "level.nextLevel",
                        defaultValue: "Next level →"
                    ))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(spacing: 14) {
            if let prompt = echoedPrompt, !prompt.isEmpty {
                summaryRow(
                    label: String(
                        localized: "celebration.yourSentence",
                        defaultValue: "Your sentence"
                    ),
                    value: prompt,
                    valueColor: .primary,
                    valueFont: .body.weight(.medium)
                )
            }
            if let candidate = topCandidate {
                Divider()
                summaryRow(
                    label: String(
                        localized: "celebration.aiNextWord",
                        defaultValue: "AI's next word"
                    ),
                    value: candidate.text.isEmpty ? "—" : candidate.text,
                    valueColor: .primary,
                    valueFont: .title.weight(.bold)
                )
                Divider()
                summaryRow(
                    label: String(
                        localized: "celebration.probability",
                        defaultValue: "Probability"
                    ),
                    value: percentString(candidate.probability),
                    valueColor: passColor,
                    valueFont: .system(size: 32, weight: .bold)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func summaryRow(
        label: String,
        value: String,
        valueColor: Color,
        valueFont: Font
    ) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.center)
        }
    }

    private func percentString(_ probability: Double) -> String {
        "\(Int((probability * 100).rounded()))%"
    }
}

#Preview {
    PassCelebrationView(
        echoedPrompt: "中华人民共和",
        topCandidate: TokenCandidate(id: 1, text: "国", probability: 0.95),
        onContinue: {},
        onGoToNextLevel: {}
    )
}
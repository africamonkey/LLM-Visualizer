//
//  ChallengeIntroCard.swift
//

import SwiftUI

struct ChallengeIntroCard: View {

    let bestSoFar: Double
    let onAccept: () -> Void

    private var goalText: String {
        let pct = Int((Level1ViewModel.passThreshold * 100).rounded())
        let format = String(
            localized: "Goal: Get AI's next-word prediction above %d%%",
            defaultValue: "Goal: Get AI's next-word prediction above %d%%"
        )
        return String(format: format, pct)
    }

    private var anchorText: String {
        let pct = Int((bestSoFar * 100).rounded())
        let format = String(
            localized: "Your highest was just %d%% — try the challenge",
            defaultValue: "Your highest was just %d%% — try the challenge"
        )
        return String(format: format, pct)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "You might have noticed…", defaultValue: "You might have noticed…"))
                .font(.headline)
            Text(String(localized: "Sometimes AI is sure, sometimes it's hesitant.", defaultValue: "Sometimes AI is sure, sometimes it's hesitant."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(
                localized: "Can you find a sentence that makes AI so sure it could guess right with its eyes closed?",
                defaultValue: "Can you find a sentence that makes AI so sure it could guess right with its eyes closed?"
            ))
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                chip(text: goalText, accent: true)
                chip(text: anchorText, accent: false)
            }
            Button(action: onAccept) {
                Text(String(localized: "I'm ready", defaultValue: "I'm ready"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22).fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    private func chip(text: String, accent: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(accent ? Color.accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    accent ? Color.accentColor.opacity(0.10) : Color(.systemGray5)
                )
            )
    }
}

#Preview {
    ChallengeIntroCard(bestSoFar: 0.68, onAccept: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
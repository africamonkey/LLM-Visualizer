//
//  ChallengeIntroCard.swift
//

import SwiftUI

struct ChallengeIntroCard: View {

    let onAccept: () -> Void

    private var goalText: String {
        let pct = Int((Level1ViewModel.passThreshold * 100).rounded())
        let format = String(
            localized: "Goal: Get AI's next-word prediction above %d%%",
            defaultValue: "Goal: Get AI's next-word prediction above %d%%"
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
                localized: "challenge.body",
                defaultValue: "You just saw how a model thinks. Now try it for real."
            ))
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                chip(text: goalText, accent: true)
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
    ChallengeIntroCard(onAccept: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

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
            localized: "目标：让 AI 对下一个词的预测超过 %d%%",
            defaultValue: "目标：让 AI 对下一个词的预测超过 %d%%"
        )
        return String(format: format, pct)
    }

    private var anchorText: String {
        let pct = Int((bestSoFar * 100).rounded())
        let format = String(
            localized: "你刚才最高才 %d%%，挑战一下",
            defaultValue: "你刚才最高才 %d%%，挑战一下"
        )
        return String(format: format, pct)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "你可能发现了…", defaultValue: "你可能发现了…"))
                .font(.headline)
            Text(String(localized: "有时候 AI 很确定，有时候很犹豫。", defaultValue: "有时候 AI 很确定，有时候很犹豫。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(
                localized: "你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？",
                defaultValue: "你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？"
            ))
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                chip(text: goalText, accent: true)
                chip(text: anchorText, accent: false)
            }
            Button(action: onAccept) {
                Text(String(localized: "我准备好了", defaultValue: "我准备好了"))
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
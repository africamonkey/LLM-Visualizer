//
//  OpeningView.swift
//

import SwiftUI

struct OpeningView: View {

    let candidates: [TokenCandidate]
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "你的输入", defaultValue: "你的输入"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("今天天气真")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )

            if isLoading {
                ProgressView()
                    .padding(.vertical, 40)
            } else {
                ProbabilityBarsView(candidates: candidates)
            }

            Text(String(
                localized: "它没在想，只是给每个词打分。",
                defaultValue: "它没在想，只是给每个词打分。"
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: onTap) {
                Text(String(
                    localized: "这是真的吗？我来试试",
                    defaultValue: "这是真的吗？我来试试"
                ))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    OpeningView(
        candidates: [
            TokenCandidate(id: 1, text: "好", probability: 0.32),
            TokenCandidate(id: 2, text: "不", probability: 0.18),
            TokenCandidate(id: 3, text: "的", probability: 0.14),
            TokenCandidate(id: 4, text: "很", probability: 0.09),
        ],
        isLoading: false,
        onTap: {}
    )
}
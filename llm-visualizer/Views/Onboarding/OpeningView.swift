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
                Text(String(localized: "Your input", defaultValue: "Your input"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "Opening prompt", defaultValue: "Today's weather is"))
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
                localized: "It's not thinking — it's just scoring every word.",
                defaultValue: "It's not thinking — it's just scoring every word."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: onTap) {
                Text(String(
                    localized: "Is that real? Let me try",
                    defaultValue: "Is that real? Let me try"
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
            TokenCandidate(id: 1, text: " good", probability: 0.32),
            TokenCandidate(id: 2, text: " not", probability: 0.18),
            TokenCandidate(id: 3, text: " the", probability: 0.14),
            TokenCandidate(id: 4, text: " very", probability: 0.09),
        ],
        isLoading: false,
        onTap: {}
    )
}
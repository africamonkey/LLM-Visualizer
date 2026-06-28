//
//  ExampleCardView.swift
//

import SwiftUI

struct ExampleCardView: View {

    let prompt: String
    let candidates: [TokenCandidate]
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt)
                .font(.title3.weight(.semibold))
            ProbabilityListView(candidates: candidates)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ProbabilityListView: View {

    let candidates: [TokenCandidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(candidates.prefix(4).enumerated()), id: \.offset) { _, c in
                ProbabilityRow(token: c.text, probability: c.probability)
            }
        }
    }
}

private struct ProbabilityRow: View {

    let token: String
    let probability: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(token)
                .font(.body.monospaced())
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: probability))
                        .frame(width: geo.size.width * CGFloat(probability))
                }
            }
            .frame(height: 12)
            Text("\(Int((probability * 100).rounded()))%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func color(for probability: Double) -> Color {
        switch probability {
        case 0.50...:        return .green
        case 0.25..<0.50:    return .orange
        case 0.10..<0.25:    return .yellow
        default:             return .red
        }
    }
}
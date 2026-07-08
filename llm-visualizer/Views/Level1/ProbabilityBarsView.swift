//
//  ProbabilityBarsView.swift
//

import SwiftUI

struct ProbabilityBarsView: View {

    let candidates: [TokenCandidate]
    var isPassed: Bool = false

    private var top1: TokenCandidate? { candidates.first }
    private var others: [TokenCandidate] { Array(candidates.dropFirst().prefix(3)) }

    private var passColor: Color { Color(red: 0.13, green: 0.77, blue: 0.37) } // #22c55e
    private var accent: Color { isPassed ? passColor : Color.accentColor }
    private var muted: Color { isPassed ? passColor.opacity(0.7) : Color.accentColor.opacity(0.65) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            top1Card
            if !others.isEmpty {
                Text(String(localized: "Other possibilities", defaultValue: "Other possibilities"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                VStack(spacing: 6) {
                    ForEach(others) { c in
                        row(for: c)
                    }
                }
            }
        }
    }

    private var top1Card: some View {
        VStack(spacing: 6) {
            Text(String(localized: "AI's most likely next word", defaultValue: "AI's most likely next word"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(top1?.text ?? "—")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(percentString(top1?.probability))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPassed ? passColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func row(for c: TokenCandidate) -> some View {
        HStack(spacing: 10) {
            Text(c.text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(muted)
                        .frame(width: barWidth(for: c.probability, in: geo.size.width))
                }
            }
            .frame(height: 10)
            Text(percentString(c.probability))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemBackground))
        )
    }

    /// Bar width: 0 for zero probability; at least 4pt for any non-zero probability
    /// so very small values stay visible.
    private func barWidth(for probability: Double, in total: CGFloat) -> CGFloat {
        if probability <= 0 { return 0 }
        return max(4, total * CGFloat(probability))
    }

    private func percentString(_ p: Double?) -> String {
        guard let p else { return "—" }
        return String(format: "%.0f%%", p * 100)
    }
}

#Preview {
    VStack {
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: " good", probability: 0.32),
            TokenCandidate(id: 2, text: " not", probability: 0.18),
            TokenCandidate(id: 3, text: " the", probability: 0.14),
            TokenCandidate(id: 4, text: " very", probability: 0.09),
        ])
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: " country", probability: 0.95),
        ], isPassed: true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
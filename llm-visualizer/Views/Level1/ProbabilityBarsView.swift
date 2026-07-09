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
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(percentString(top1?.probability))
                .font(.title2.weight(.semibold))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(top1AccessibilityLabel)
    }

    private var top1AccessibilityLabel: String {
        let token = top1?.text ?? "no prediction"
        let pct = Int(((top1?.probability ?? 0) * 100).rounded())
        return "\(token), \(pct) percent"
    }

    private func row(for c: TokenCandidate) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(c.text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 120, alignment: .leading)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(c.text), \(Int((c.probability * 100).rounded())) percent")
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
    VStack(spacing: 24) {
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: " good", probability: 0.32),
            TokenCandidate(id: 2, text: " not", probability: 0.18),
            TokenCandidate(id: 3, text: " the", probability: 0.14),
            TokenCandidate(id: 4, text: " very", probability: 0.09),
        ])
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: " country", probability: 0.95),
        ], isPassed: true)
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: " internationalization", probability: 0.42),
            TokenCandidate(id: 2, text: " not", probability: 0.18),
            TokenCandidate(id: 3, text: " supercalifragilisticexpialidocious", probability: 0.14),
            TokenCandidate(id: 4, text: " the", probability: 0.09),
        ])
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
//
//  ExampleCardView.swift
//

import SwiftUI

struct ExampleCardView: View {

    let prompt: String
    let candidates: [TokenCandidate]
    let caption: String

    var body: some View {
        VStack(spacing: 0) {
            promptHeader
                .padding(.top, 36)
                .padding(.bottom, 28)

            ProbabilityListView(candidates: candidates)
                .padding(.horizontal, 24)

            Text(caption)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var promptHeader: some View {
        VStack(spacing: 10) {
            Text(String(
                localized: "onboarding.example.framing",
                defaultValue: "The model has to guess what comes next"
            ))
            .font(.caption2.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            Text(prompt)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
    }
}

private struct ProbabilityListView: View {

    let candidates: [TokenCandidate]
    @State private var animatedProbabilities: [Double]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(candidates: [TokenCandidate]) {
        self.candidates = candidates
        let count = min(candidates.count, 4)
        self._animatedProbabilities = State(initialValue: Array(repeating: 0.0, count: count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(candidates.prefix(4).enumerated()), id: \.offset) { index, c in
                ProbabilityRow(
                    token: c.text,
                    probability: c.probability,
                    animatedProbability: animatedProbabilities[safe: index] ?? 0,
                    isTopCandidate: index == 0
                )
            }
        }
        .onAppear { animateIn() }
    }

    private func animateIn() {
        let count = min(candidates.count, 4)
        guard count > 0 else { return }

        if reduceMotion {
            for index in 0..<count {
                animatedProbabilities[index] = candidates[index].probability
            }
            return
        }

        for index in 0..<count {
            let delay = Double(index) * 0.08 + 0.2
            let target = candidates[index].probability
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    if index < animatedProbabilities.count {
                        animatedProbabilities[index] = target
                    }
                }
            }
        }
    }
}

private struct ProbabilityRow: View {

    let token: String
    let probability: Double
    let animatedProbability: Double
    let isTopCandidate: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(token)
                .font(isTopCandidate ? .title3.weight(.bold) : .body)
                .foregroundStyle(isTopCandidate ? .primary : .secondary)
                .frame(width: 76, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(isTopCandidate ? 0.18 : 0.12))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(animatedProbability))
                }
            }
            .frame(height: isTopCandidate ? 18 : 10)

            Text("\(Int((probability * 100).rounded()))%")
                .font(isTopCandidate ? .body.weight(.semibold) : .callout.monospacedDigit())
                .foregroundStyle(isTopCandidate ? .primary : .secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, isTopCandidate ? 12 : 0)
        .padding(.vertical, isTopCandidate ? 10 : 0)
        .background(
            isTopCandidate
                ? RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                : nil
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var color: Color {
        switch probability {
        case 0.50...:        return .green
        case 0.25..<0.50:    return .orange
        case 0.10..<0.25:    return .yellow
        default:             return .red
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
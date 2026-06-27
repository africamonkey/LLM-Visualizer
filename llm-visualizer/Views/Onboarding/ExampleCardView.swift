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
            DotGridView(candidates: candidates)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DotGridView: View {

    let candidates: [TokenCandidate]
    private let columns = Array(
        repeating: GridItem(.fixed(14), spacing: 4),
        count: 10
    )

    private static let palette: [Color] = [
        .green, .orange, .yellow, .red
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<100, id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func color(for index: Int) -> Color {
        var remaining = index
        for (i, c) in candidates.prefix(4).enumerated() {
            let count = Int((c.probability * 100).rounded())
            if remaining < count {
                return Self.palette[min(i, Self.palette.count - 1)]
            }
            remaining -= count
        }
        return Color.gray.opacity(0.15)
    }
}

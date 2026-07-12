//
//  LevelHeaderView.swift
//

import SwiftUI

struct LevelHeaderView<Trailing: View>: View {

    let levelNumber: Int
    let subtitle: String
    let goalDescription: String
    let bestSoFar: LevelSession.BestSoFarKind
    let isComplete: Bool
    @ViewBuilder let trailing: () -> Trailing

    init(
        levelNumber: Int,
        subtitle: String,
        goalDescription: String,
        bestSoFar: LevelSession.BestSoFarKind,
        isComplete: Bool,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.levelNumber = levelNumber
        self.subtitle = subtitle
        self.goalDescription = goalDescription
        self.bestSoFar = bestSoFar
        self.isComplete = isComplete
        self.trailing = trailing
    }

    private var titleText: String {
        let format = String(
            localized: "Level %d",
            defaultValue: "Level %d"
        )
        return String(format: format, levelNumber)
    }

    private var goalText: String {
        // Goal text comes straight from the session's `goalDescription`. The
        // previous implementation hardcoded "Top-1 probability above 90%"
        // using `Level1ViewModel.passThreshold`, which meant Level 2 also
        // showed Level 1's goal — wrong.
        goalDescription
    }

    private var bestText: String? {
        switch bestSoFar {
        case .probability(let value):
            let pct = Int((value * 100).rounded())
            let format = String(
                localized: "Best record: %d%%",
                defaultValue: "Best record: %d%%"
            )
            return String(format: format, pct)
        case .characterCount(let count):
            let format = String(
                localized: "Best record: %d chars",
                defaultValue: "Best record: %d chars"
            )
            return String(format: format, count)
        case .none:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(titleText)
                    .font(.headline)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if isComplete {
                    Text("✓")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.13, green: 0.77, blue: 0.37))
                }
                Spacer()
                trailing()
            }
            HStack(spacing: 8) {
                Text(goalText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let bestText {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(bestText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack(spacing: 16) {
        LevelHeaderView(
            levelNumber: 1,
            subtitle: "Make AI guess right with its eyes closed",
            goalDescription: "Get Top-1 probability above 90%",
            bestSoFar: .probability(0.32),
            isComplete: false
        )
        LevelHeaderView(
            levelNumber: 1,
            subtitle: "Make AI guess right with its eyes closed",
            goalDescription: "Get Top-1 probability above 90%",
            bestSoFar: .probability(0.95),
            isComplete: true
        )
        LevelHeaderView(
            levelNumber: 2,
            subtitle: "It reads the world in blocks",
            goalDescription: "Find content that fits in a single block",
            bestSoFar: .characterCount(42),
            isComplete: false
        )
        LevelHeaderView(
            levelNumber: 3,
            subtitle: "Placeholder",
            goalDescription: "TBD",
            bestSoFar: .none,
            isComplete: false
        )
    }
}

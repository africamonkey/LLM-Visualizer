//
//  LevelHeaderView.swift
//

import SwiftUI

struct LevelHeaderView<Trailing: View>: View {

    let levelNumber: Int
    let subtitle: String
    let goalDescription: String
    let bestSoFar: Double
    let isComplete: Bool
    @ViewBuilder let trailing: () -> Trailing

    init(
        levelNumber: Int,
        subtitle: String,
        goalDescription: String,
        bestSoFar: Double,
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
        let pct = Int((Level1ViewModel.passThreshold * 100).rounded())
        let format = String(
            localized: "Goal: Get Top-1 probability above %d%%",
            defaultValue: "Goal: Get Top-1 probability above %d%%"
        )
        return String(format: format, pct)
    }

    private var bestText: String {
        let pct = Int((bestSoFar * 100).rounded())
        let format = String(
            localized: "Best record: %d%%",
            defaultValue: "Best record: %d%%"
        )
        return String(format: format, pct)
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
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(bestText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            bestSoFar: 0.32,
            isComplete: false
        )
        LevelHeaderView(
            levelNumber: 1,
            subtitle: "Make AI guess right with its eyes closed",
            goalDescription: "Get Top-1 probability above 90%",
            bestSoFar: 0.95,
            isComplete: true
        )
    }
}

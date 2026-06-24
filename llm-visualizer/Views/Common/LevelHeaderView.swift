//
//  LevelHeaderView.swift
//

import SwiftUI

struct LevelHeaderView: View {

    let levelNumber: Int
    let subtitle: String
    let goalDescription: String
    let bestSoFar: Double
    let isComplete: Bool

    private var titleText: String {
        let format = String(
            localized: "第 %d 关",
            defaultValue: "第 %d 关"
        )
        return String(format: format, levelNumber)
    }

    private var goalText: String {
        let pct = Int((Level1ViewModel.passThreshold * 100).rounded())
        let format = String(
            localized: "目标：让 Top-1 概率超过 %d%%",
            defaultValue: "目标：让 Top-1 概率超过 %d%%"
        )
        return String(format: format, pct)
    }

    private var bestText: String {
        let pct = Int((bestSoFar * 100).rounded())
        let format = String(
            localized: "最高纪录：%d%%",
            defaultValue: "最高纪录：%d%%"
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
            subtitle: "让 AI 闭眼都猜对",
            goalDescription: "目标：让 Top-1 概率超过 90%",
            bestSoFar: 0.32,
            isComplete: false
        )
        LevelHeaderView(
            levelNumber: 1,
            subtitle: "让 AI 闭眼都猜对",
            goalDescription: "目标：让 Top-1 概率超过 90%",
            bestSoFar: 0.95,
            isComplete: true
        )
    }
}

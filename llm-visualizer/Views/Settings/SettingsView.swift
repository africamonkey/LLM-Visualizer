//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {

    let onJumpToLevel: (Int) -> Void
    let onReplayOnboarding: () -> Void
    let onReset: () -> Void
    let currentLevelIndex: Int
    let levels: [LevelSummary]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        Button {
                            onJumpToLevel(index)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(level.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if index == currentLevelIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(String(
                        localized: "settings.levelsHeader",
                        defaultValue: "Levels"
                    ))
                }
                Section {
                    Button {
                        onReplayOnboarding()
                        dismiss()
                    } label: {
                        Text(String(
                            localized: "settings.replayOnboarding",
                            defaultValue: "Replay onboarding"
                        ))
                    }
                }
                Section {
                    Button(role: .destructive) {
                        onReset()
                        dismiss()
                    } label: {
                        Text(String(
                            localized: "settings.resetProgress",
                            defaultValue: "Reset all progress"
                        ))
                    }
                } footer: {
                    Text(String(
                        localized: "settings.resetFooter",
                        defaultValue: "Clears onboarding state, completed levels, and best records."
                    ))
                }
            }
            .navigationTitle(String(
                localized: "settings.title",
                defaultValue: "Settings"
            ))
        }
    }
}

#Preview {
    SettingsView(
        onJumpToLevel: { _ in },
        onReplayOnboarding: {},
        onReset: {},
        currentLevelIndex: 0,
        levels: [
            LevelSummary(id: 1, title: "Level 1", subtitle: "Make AI guess right"),
            LevelSummary(id: 2, title: "Level 2", subtitle: "It reads the world in blocks"),
        ]
    )
}
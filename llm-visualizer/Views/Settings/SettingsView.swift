//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    let onReplayOnboarding: () -> Void
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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
    SettingsView(onReplayOnboarding: {}, onReset: {})
}

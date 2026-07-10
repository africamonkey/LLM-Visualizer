//
//  LevelShellView.swift
//

import SwiftUI

struct LevelShellView: View {

    @State var currentSession: LevelSession
    @State private var dismissed: Bool = false
    @State private var showSettings: Bool = false
    let onReset: () -> Void

    @MainActor
    init(currentSession: LevelSession, onReset: @escaping () -> Void) {
        self.currentSession = currentSession
        self.onReset = onReset
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LevelHeaderView(
                    levelNumber: currentSession.id,
                    subtitle: currentSession.subtitle,
                    goalDescription: currentSession.goalDescription,
                    bestSoFar: bestSoFar,
                    isComplete: currentSession.isComplete,
                    trailing: {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                        .accessibilityLabel(String(
                            localized: "settings.title",
                            defaultValue: "Settings"
                        ))
                    }
                )
                Divider()
                currentSession.makeContentView()
            }

            if let level1 = currentSession as? Level1Session,
               level1.viewModel.state == .passed,
               !dismissed {
                PassCelebrationView(
                    echoedPrompt: level1.viewModel.prompt,
                    topCandidate: level1.viewModel.topCandidates.first,
                    onContinue: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            dismissed = true
                            level1.viewModel.dismissCelebration()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                onReplayOnboarding: onReset,
                onReset: onReset
            )
        }
        .onChange(of: level1State) { _, newValue in
            // Re-enable the celebration overlay after each new .passed transition,
            // so the second / third / nth pass still re-fires it.
            if newValue == .passed {
                dismissed = false
            }
        }
        .task {
            // Model is already loaded by AppShellViewModel before we get here.
            // (No-op task keeps SwiftUI's lifecycle behavior identical.)
        }
    }

    private var level1State: Level1ViewModel.State? {
        (currentSession as? Level1Session)?.viewModel.state
    }

    private var bestSoFar: Double {
        (currentSession as? Level1Session)?.viewModel.bestSoFar ?? 0.0
    }
}
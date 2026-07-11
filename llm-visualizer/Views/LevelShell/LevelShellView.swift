//
//  LevelShellView.swift
//

import SwiftUI

struct LevelShellView: View {

    // currentSession comes from the parent (AppRootView). It must NOT be
    // @State — @State ignores subsequent init values, which would silently
    // freeze LevelShellView on whatever session was passed first. The two
    // @State properties below are owned by this view (UI-only flags).
    var currentSession: LevelSession
    @State private var dismissed: Bool = false
    @State private var showSettings: Bool = false
    let hasNextLevel: Bool
    let onAdvanceLevel: () -> Void
    let onJumpToLevel: (Int) -> Void
    let onReset: () -> Void

    @MainActor
    init(
        currentSession: LevelSession,
        hasNextLevel: Bool,
        onAdvanceLevel: @escaping () -> Void,
        onJumpToLevel: @escaping (Int) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.currentSession = currentSession
        self.hasNextLevel = hasNextLevel
        self.onAdvanceLevel = onAdvanceLevel
        self.onJumpToLevel = onJumpToLevel
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
            .onAppear {
                // Wire Level 1's "next level" affordance to the shell's
                // advance callback. Done here (not in the factory) because
                // the closure is created at the shell layer, not at AppRoot.
                if let level1 = currentSession as? Level1Session {
                    level1.onGoToNextLevel = hasNextLevel ? onAdvanceLevel : nil
                }
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
                    },
                    onGoToNextLevel: hasNextLevel ? onAdvanceLevel : nil
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                onJumpToLevel: { index in
                    showSettings = false
                    onJumpToLevel(index)
                },
                onReplayOnboarding: onReset,
                onReset: onReset,
                currentLevelIndex: currentSession.id - 1,
                levels: LevelRegistry.all.map { $0.summary }
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

    private var bestSoFar: LevelSession.BestSoFarKind {
        currentSession.bestSoFar
    }
}
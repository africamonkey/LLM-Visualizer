//
//  LevelShellView.swift
//

import SwiftUI

struct LevelShellView: View {

    @State var currentSession: LevelSession
    @State private var dismissed: Bool = false

    @MainActor
    init(currentSession: LevelSession) {
        self.currentSession = currentSession
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LevelHeaderView(
                    levelNumber: currentSession.id,
                    subtitle: currentSession.subtitle,
                    goalDescription: currentSession.goalDescription,
                    bestSoFar: bestSoFar,
                    isComplete: currentSession.isComplete
                )
                Divider()
                currentSession.makeContentView()
            }

            if let level1 = currentSession as? Level1Session,
               level1.viewModel.state == .passed,
               !dismissed {
                PassCelebrationView(
                    echoedPrompt: level1.viewModel.prompt,
                    onContinue: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            dismissed = true
                        }
                    }
                )
            }
        }
        .task {
            // Model is already loaded by AppShellViewModel before we get here.
            // (No-op task keeps SwiftUI's lifecycle behavior identical.)
        }
    }

    private var bestSoFar: Double {
        (currentSession as? Level1Session)?.viewModel.bestSoFar ?? 0.0
    }
}
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
                    onContinue: { withAnimation { dismissed = true } }
                )
            }
        }
        .task {
            // Skip model load during unit/UI tests — Metal doesn't init in simulator
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            if let level1 = currentSession as? Level1Session {
                await level1.bootstrap()
            }
        }
    }

    private var bestSoFar: Double {
        (currentSession as? Level1Session)?.viewModel.bestSoFar ?? 0.0
    }
}
//
//  Level1Session.swift
//

import SwiftUI

@MainActor
final class Level1Session: LevelSession {

    let viewModel: Level1ViewModel

    /// Closure invoked when the user taps "Next level →" on Level 1.
    /// Set by `LevelShellView` after the session is constructed. Nil when
    /// Level 1 is the last level (the button hides).
    var onGoToNextLevel: (() -> Void)?

    init(viewModel: Level1ViewModel) {
        self.viewModel = viewModel
        super.init(
            id: 1,
            title: String(localized: "Level 1", defaultValue: "Level 1"),
            subtitle: String(
                localized: "Make AI guess right with its eyes closed",
                defaultValue: "Make AI guess right with its eyes closed"
            ),
            goalDescription: String(
                localized: "Get Top-1 probability above 90%",
                defaultValue: "Get Top-1 probability above 90%"
            )
        )
    }

    override func makeContentView() -> AnyView {
        AnyView(
            Level1View(
                viewModel: viewModel,
                session: self,
                showNarrator: true,
                onGoToNextLevel: onGoToNextLevel
            )
        )
    }

    override var bestSoFar: BestSoFarKind {
        .probability(viewModel.bestSoFar)
    }

    override func evaluate() {
        if viewModel.state == .passed, !isComplete {
            isComplete = true
        }
    }

    /// Construct a Level1Session with its view model wired to the given service.
    /// Used by the level navigation logic in `AppRootView`.
    static func make(service: LLMServiceProtocol) -> Level1Session {
        Level1Session(viewModel: Level1ViewModel(service: service))
    }
}
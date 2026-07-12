//
//  Level2Session.swift
//

import SwiftUI

@MainActor
final class Level2Session: LevelSession {

    let viewModel: Level2ViewModel

    init(viewModel: Level2ViewModel) {
        self.viewModel = viewModel
        super.init(
            id: 2,
            title: String(localized: "level2.title", defaultValue: "Level 2"),
            subtitle: String(
                localized: "level2.subtitle",
                defaultValue: "It reads the world in blocks"
            ),
            goalDescription: String(
                localized: "level2.goal",
                defaultValue: "Find content that fits in a single block"
            )
        )
    }

    override func makeContentView() -> AnyView {
        AnyView(Level2FlowView(viewModel: viewModel))
    }

    override var bestSoFar: LevelSession.BestSoFarKind {
        .characterCount(viewModel.bestCharCount)
    }

    override func evaluate() {
        if viewModel.bestCharCount > 0, !isComplete {
            isComplete = true
        }
    }

    /// Construct a Level2Session with its view model wired to the given service.
    /// Pass `skipIntro: true` when entering Level 2 from another level so the
    /// user lands directly on the playing surface (B4).
    static func make(service: LLMServiceProtocol, skipIntro: Bool = false) -> Level2Session {
        Level2Session(
            viewModel: Level2ViewModel(service: service, skipIntro: skipIntro)
        )
    }
}

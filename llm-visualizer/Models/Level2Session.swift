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

    override func evaluate() {
        if viewModel.bestCharCount > 0, !isComplete {
            isComplete = true
        }
    }
}

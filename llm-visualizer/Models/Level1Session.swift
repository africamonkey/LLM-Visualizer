//
//  Level1Session.swift
//

import SwiftUI

@MainActor
final class Level1Session: LevelSession {

    let viewModel: Level1ViewModel

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
                showNarrator: true
            )
        )
    }

    override func evaluate() {
        if viewModel.state == .passed, !isComplete {
            isComplete = true
        }
    }

    func bootstrap() async {
        await viewModel.bootstrap()
    }
}
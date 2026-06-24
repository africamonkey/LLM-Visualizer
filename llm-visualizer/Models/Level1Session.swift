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
            title: String(localized: "第 1 关", defaultValue: "第 1 关"),
            subtitle: String(
                localized: "让 AI 闭眼都猜对",
                defaultValue: "让 AI 闭眼都猜对"
            ),
            goalDescription: String(
                localized: "让 Top-1 概率超过 90%",
                defaultValue: "让 Top-1 概率超过 90%"
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
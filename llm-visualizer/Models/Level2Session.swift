//
//  Level2Session.swift
//

import SwiftUI

@MainActor
final class Level2Session: LevelSession {

    init() {
        super.init(
            id: 2,
            title: String(localized: "Level 2", defaultValue: "Level 2"),
            subtitle: String(
                localized: "level2.subtitle",
                defaultValue: "Coming soon"
            ),
            goalDescription: String(
                localized: "level2.goal",
                defaultValue: "Level 2 in progress"
            )
        )
    }

    override func makeContentView() -> AnyView {
        AnyView(Level2View())
    }
}

//
//  Levels.swift
//

import SwiftUI

@MainActor
@Observable
class LevelSession {
    let id: Int
    let title: String
    let subtitle: String
    let goalDescription: String

    var isComplete: Bool {
        didSet { ProgressStore.shared.setComplete(id, isComplete) }
    }

    init(id: Int, title: String, subtitle: String, goalDescription: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.goalDescription = goalDescription
        self.isComplete = ProgressStore.shared.isComplete(id)
    }

    /// Subclasses override to provide the level's main SwiftUI view.
    func makeContentView() -> AnyView {
        fatalError("Subclass must override makeContentView()")
    }

    /// Subclasses override to check if the goal has been met and
    /// mutate `isComplete` accordingly. Default: no-op.
    func evaluate() {}
}

/// Minimal placeholder so `LevelRegistry.all` has at least one entry
/// (required by the `registryContainsAtLeastOne` test). The full
/// implementation — view model, content view, evaluate logic — is
/// defined in a later task that will replace this stub.
@MainActor
final class Level1Session: LevelSession {
    init() {
        super.init(
            id: 1,
            title: "Level 1",
            subtitle: "Send your first message",
            goalDescription: "Complete your first chat turn."
        )
    }

    override func makeContentView() -> AnyView {
        AnyView(Text("Level 1 — coming soon"))
    }
}

enum LevelRegistry {
    /// Ordered list of level classes. App picks the first
    /// not-yet-complete one as the current level. Future slices
    /// append entries here.
    static let all: [LevelSession.Type] = [
        Level1Session.self
    ]
}

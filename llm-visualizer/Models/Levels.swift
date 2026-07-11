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

    /// What to show in the header's "best so far" pill.
    enum BestSoFarKind: Equatable {
        case probability(Double)
        case characterCount(Int)
        case none
    }

    /// Subclasses override to expose their persisted best metric.
    var bestSoFar: BestSoFarKind { .none }

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

/// Compact level metadata shown by the Settings → Levels picker.
struct LevelSummary: Equatable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
}

enum LevelRegistry {
    /// Each entry pairs the session class with picker-display metadata so
    /// the Settings → Levels screen can show what's available without
    /// instantiating a real session.
    struct Entry {
        let type: LevelSession.Type
        let summary: LevelSummary
    }

    /// Ordered list of level entries. App picks the first not-yet-complete
    /// one as the current level. Future slices append entries here.
    static let all: [Entry] = [
        Entry(
            type: Level1Session.self,
            summary: LevelSummary(
                id: 1,
                title: String(localized: "Level 1", defaultValue: "Level 1"),
                subtitle: String(
                    localized: "Make AI guess right with its eyes closed",
                    defaultValue: "Make AI guess right with its eyes closed"
                )
            )
        ),
        Entry(
            type: Level2Session.self,
            summary: LevelSummary(
                id: 2,
                title: String(localized: "Level 2", defaultValue: "Level 2"),
                subtitle: String(
                    localized: "It reads the world in blocks",
                    defaultValue: "It reads the world in blocks"
                )
            )
        ),
    ]
}

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

enum LevelRegistry {
    /// Ordered list of level classes. App picks the first
    /// not-yet-complete one as the current level. Future slices
    /// append entries here.
    static let all: [LevelSession.Type] = [
        Level1Session.self,
        Level2Session.self
    ]
}

//
//  LevelProgress.swift
//

import Foundation

final class ProgressStore: @unchecked Sendable {

    static let shared = ProgressStore(defaults: .standard)

    private let defaults: UserDefaults
    private let seenOnboardingKey = "llmviz.hasSeenOnboarding"
    private let completedKey = "llmviz.completedLevels"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: seenOnboardingKey) }
        set { defaults.set(newValue, forKey: seenOnboardingKey) }
    }

    func isComplete(_ levelId: Int) -> Bool {
        completedLevels.contains(levelId)
    }

    func setComplete(_ levelId: Int, _ value: Bool) {
        var set = completedLevels
        if value {
            set.insert(levelId)
        } else {
            set.remove(levelId)
        }
        defaults.set(Array(set).sorted(), forKey: completedKey)
    }

    private var completedLevels: Set<Int> {
        Set((defaults.array(forKey: completedKey) as? [Int]) ?? [])
    }
}

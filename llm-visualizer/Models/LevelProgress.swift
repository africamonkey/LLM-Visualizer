//
//  LevelProgress.swift
//

import Foundation

final class ProgressStore: @unchecked Sendable {

    static let shared = ProgressStore(defaults: .standard)

    private let defaults: UserDefaults
    private let seenOnboardingKey = "llmviz.hasSeenOnboarding"
    private let completedKey = "llmviz.completedLevels"
    private let bestKey = "llmviz.bestProbabilities"

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

    func bestProbability(_ levelId: Int) -> Double {
        bestMap[levelId] ?? 0.0
    }

    func setBestProbability(_ levelId: Int, _ value: Double) {
        let clamped = max(0.0, min(1.0, value))
        var map = bestMap
        if let existing = map[levelId], existing >= clamped { return }
        map[levelId] = clamped
        defaults.set(map.mapKeys { String($0) }, forKey: bestKey)
    }

    private var completedLevels: Set<Int> {
        Set((defaults.array(forKey: completedKey) as? [Int]) ?? [])
    }

    private var bestMap: [Int: Double] {
        guard let raw = defaults.dictionary(forKey: bestKey) else { return [:] }
        var out: [Int: Double] = [:]
        for (k, v) in raw {
            guard let id = Int(k) else { continue }
            if let n = v as? Double { out[id] = n }
            else if let n = v as? NSNumber { out[id] = n.doubleValue }
        }
        return out
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var out: [T: Value] = [:]
        for (k, v) in self { out[transform(k)] = v }
        return out
    }
}

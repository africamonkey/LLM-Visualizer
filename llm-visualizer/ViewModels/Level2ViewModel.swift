//
//  Level2ViewModel.swift
//

import Foundation

@MainActor
@Observable
final class Level2ViewModel {

    enum Step: Equatable {
        case hook
        case demo
        case challengeIntro
        case playing
        case passed
    }

    enum HintTier: Int, Equatable {
        case none = 0
        case direction = 1
        case example = 2
    }

    // `service` is intentionally non-`private` so tests can mutate the
    // mock mid-test (e.g., clear `tokenizeError` after a recovery check).
    // Mirrors `AppShellViewModel.service`.
    let service: LLMServiceProtocol
    private let progressStore: ProgressStore
    private let hint2ExampleText: String

    var step: Step = .hook

    var rawText: String = "" {
        didSet {
            guard oldValue != rawText else { return }
            onRawTextChanged()
        }
    }
    var tokens: [TokenPiece] = []
    var attemptCount: Int = 0
    var hintTier: HintTier = .none

    private(set) var bestCharCount: Int = 0
    private(set) var isPassing: Bool = false
    var isPassed: Bool { bestCharCount > 0 || progressStore.isComplete(2) }

    var errorBanner: String?
    private(set) var tokenizeTask: Task<Void, Never>?

    init(service: LLMServiceProtocol,
         progressStore: ProgressStore = .shared,
         hint2ExampleText: String = Level2Constants.hint2ExampleText) {
        self.service = service
        self.progressStore = progressStore
        self.hint2ExampleText = hint2ExampleText
        self.bestCharCount = progressStore.bestCharacterCount(2)
    }

    // --- stubs; real bodies land in Tasks 7-10 ---

    func acknowledgeHook() {}
    func acknowledgeDemo() {}
    func acknowledgeChallenge() {}
    func acknowledgePassed() {}
    func applyHint2Example() {}

    var earnedStars: Int {
        if bestCharCount >= Level2Constants.star3Threshold { return 3 }
        if bestCharCount >= Level2Constants.star2Threshold { return 2 }
        if bestCharCount >= Level2Constants.star1Threshold { return 1 }
        return 0
    }

    func waitForPendingTokenize() async {
        await tokenizeTask?.value
    }

    private func onRawTextChanged() {}
    private func checkPassAndPersist() {}
}

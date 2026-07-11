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

    func acknowledgeHook()      { step = .demo }
    func acknowledgeDemo()      { step = .challengeIntro }
    func acknowledgeChallenge() { step = .playing }
    func acknowledgePassed()    { step = .playing }
    func applyHint2Example() {
        rawText = hint2ExampleText
    }

    var earnedStars: Int {
        if bestCharCount >= Level2Constants.star3Threshold { return 3 }
        if bestCharCount >= Level2Constants.star2Threshold { return 2 }
        if bestCharCount >= Level2Constants.star1Threshold { return 1 }
        return 0
    }

    func waitForPendingTokenize() async {
        await tokenizeTask?.value
    }

    private func onRawTextChanged() {
        tokenizeTask?.cancel()
        tokenizeTask = Task { [weak self] in
            guard let self else { return }
            let text = rawText
            do {
                let pieces = try await service.tokenize(text)
                guard !Task.isCancelled else { return }
                self.tokens = pieces
                self.checkPassAndPersist()
            } catch {
                guard !Task.isCancelled else { return }
                self.errorBanner = LevelError.humanize(error)
            }
        }
    }

    private func checkPassAndPersist() {
        let charCount = rawText.count
        let trimmedNonWhitespace = rawText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count
        let tokenCount = tokens.count
        let pass = tokenCount == Level2Constants.passTokenCount
            && trimmedNonWhitespace >= Level2Constants.passMinNonWhitespace

        self.isPassing = pass

        if pass {
            if charCount > bestCharCount {
                bestCharCount = charCount
                progressStore.setBestCharacterCount(2, charCount)
            }
            step = .passed
            attemptCount = 0
            hintTier = .none
        } else if tokenCount > 1 {
            attemptCount += 1
            if attemptCount >= Level2Constants.hint2AttemptThreshold {
                hintTier = .example
            } else if attemptCount >= Level2Constants.hint1AttemptThreshold {
                hintTier = .direction
            }
        }
    }
}

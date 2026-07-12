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
    private var errorAutoClearTask: Task<Void, Never>?

    /// When true, the user starts the session already at `.playing` instead
    /// of walking the hook → demo → challengeIntro flow. Used when the user
    /// advances from Level 1 via the "Next level →" affordance.
    var step: Step

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
    /// True when the current `tokens` represent a single token block AND
    /// the input has at least one non-whitespace char. Updated in real-time
    /// as the user types (visual feedback), independent of submit.
    private(set) var isPassing: Bool = false
    /// True if the most recent pass set a new `bestCharCount` record. Cleared
    /// on `acknowledgePassed`. Drives the "NEW BEST" badge on PassedView.
    private(set) var isNewRecord: Bool = false
    var isPassed: Bool { bestCharCount > 0 || progressStore.isComplete(2) }

    var errorBanner: String?
    private(set) var tokenizeTask: Task<Void, Never>?

    init(service: LLMServiceProtocol,
         progressStore: ProgressStore = .shared,
         hint2ExampleText: String = Level2Constants.hint2ExampleText,
         skipIntro: Bool = false) {
        self.service = service
        self.progressStore = progressStore
        self.hint2ExampleText = hint2ExampleText
        self.bestCharCount = progressStore.bestCharacterCount(2)
        self.step = skipIntro ? .playing : .hook
    }

    func acknowledgeHook()      { step = .demo }
    func acknowledgeDemo()      { step = .challengeIntro }
    func acknowledgeChallenge() { step = .playing }
    func acknowledgePassed() {
        // B11: clear input + tokens so the next playing round starts fresh.
        rawText = ""
        tokens = []
        isPassing = false
        isNewRecord = false
        attemptCount = 0
        hintTier = .none
        step = .playing
    }
    func applyHint2Example() {
        rawText = hint2ExampleText
        // Don't auto-submit: user can see the autofill, edit if they want,
        // then tap Submit themselves.
    }

    /// User taps Submit. Evaluates the current `rawText` against the pass
    /// condition. If pass → step = .passed (and maybe new record). If
    /// multi-token → attemptCount++ and hint tier may escalate. No-op when
    /// input is empty/whitespace or outside `.playing`.
    func submit() {
        checkPassAndPersist()
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

    private func showError(_ message: String) {
        errorBanner = message
        errorAutoClearTask?.cancel()
        errorAutoClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if self.errorBanner == message { self.errorBanner = nil }
        }
    }

    /// Real-time visual pipeline: tokenize the input so the token block
    /// view reflects the current text. Does NOT change step or attemptCount.
    private func onRawTextChanged() {
        tokenizeTask?.cancel()
        tokenizeTask = Task { [weak self] in
            guard let self else { return }
            let text = rawText
            do {
                let pieces = try await service.tokenize(text)
                guard !Task.isCancelled else { return }
                self.tokens = pieces
                self.refreshIsPassing()
            } catch {
                guard !Task.isCancelled else { return }
                self.showError(LevelError.humanize(error))
            }
        }
    }

    /// Recompute `isPassing` from the current `rawText` + `tokens`. Pure
    /// derived state — no side effects. Used for the real-time "✨ passed"
    /// pill in PlayingView.
    private func refreshIsPassing() {
        let trimmedNonWhitespace = rawText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count
        let tokenCount = tokens.count
        isPassing = tokenCount == Level2Constants.passTokenCount
            && trimmedNonWhitespace >= Level2Constants.passMinNonWhitespace
    }

    /// Called only from `submit()`. Gates on `step == .playing` so demo /
    /// challengeIntro phases never accidentally trigger a pass transition.
    private func checkPassAndPersist() {
        // B2: pass detection is gated to the playing phase.
        guard step == .playing else { return }

        let charCount = rawText.count
        let trimmedNonWhitespace = rawText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count
        let tokenCount = tokens.count
        let pass = tokenCount == Level2Constants.passTokenCount
            && trimmedNonWhitespace >= Level2Constants.passMinNonWhitespace

        if pass {
            // B6: track whether this pass beat the previous best.
            let newRecord = charCount > bestCharCount
            isNewRecord = newRecord
            if newRecord {
                bestCharCount = charCount
                progressStore.setBestCharacterCount(2, charCount)
            }
            step = .passed
            attemptCount = 0
            hintTier = .none
        } else if tokenCount > 1 {
            // B3: attemptCount increments on a deliberate submit, not on
            // every keystroke. The hint tier escalates from here.
            attemptCount += 1
            if attemptCount >= Level2Constants.hint2AttemptThreshold {
                hintTier = .example
            } else if attemptCount >= Level2Constants.hint1AttemptThreshold {
                hintTier = .direction
            }
        }
    }
}
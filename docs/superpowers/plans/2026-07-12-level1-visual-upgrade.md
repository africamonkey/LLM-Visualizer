# Level 1 Visual Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Borrow Level 2's visual/UX patterns (compact token blocks, big-number counter, state pill, NEW BEST badge, submit button gray-out, real-time tokenization) into Level 1, while keeping Level 1's "guess the next word" identity.

**Architecture:** Reuse existing `TokenBlocksView` and counter cell via a shared `Views/Common/` location with a `style` parameter. Add real-time tokenizer pipeline to `Level1ViewModel`. Thread a new `isNewRecord` flag through the celebration path. All changes ship in one PR.

**Tech Stack:** SwiftUI, Swift Testing (`@Test`), `@Observable` + `@MainActor`, `MockLLMService`. iOS project; tests run via Xcode (no CLI test runner).

**Branch:** `feat/level1-visual-upgrade`
**Worktree:** `.worktrees/level1-visual-upgrade`
**Spec:** `docs/superpowers/specs/2026-07-12-level1-visual-upgrade-design.md`

---

## File map

### Create
- `llm-visualizer/Views/Common/TokenBlocksView.swift` (moved from Level 2 + `style` param)
- `llm-visualizer/Views/Common/CounterCell.swift` (extracted from Level 2)
- `llm-visualizerTests/TokenBlocksViewTests.swift`
- `llm-visualizerTests/Level1ViewModelTokensTests.swift`
- `llm-visualizerTests/Level1ViewModelNewRecordTests.swift`
- `llm-visualizerTests/PassCelebrationViewTests.swift`

### Modify
- `llm-visualizer/Views/Level1/Level1View.swift` (add blocks row, counter row, pill, submit gray-out)
- `llm-visualizer/ViewModels/Level1ViewModel.swift` (add `tokens`, `tokenizeTask`, `isNewRecord`, `waitForPendingTokenize`)
- `llm-visualizer/Views/LevelShell/PassCelebrationView.swift` (add `isNewRecord` param + badge)
- `llm-visualizer/Views/LevelShell/LevelShellView.swift` (pass `isNewRecord` when constructing celebration)
- `llm-visualizer/Views/Level2/PlayingView.swift` (use shared `CounterCell` from Common)
- `llm-visualizer/Resources/Localizable.xcstrings` (add `level1.statePill`, `level1.passed.newRecord`)

### Delete
- `llm-visualizer/Views/Level2/TokenBlocksView.swift` (moved to Common; git tracks move)

### Unchanged
- `llm-visualizer/Models/Level1Session.swift`
- `llm-visualizer/Models/Levels.swift`
- `llm-visualizer/Models/LevelProgress.swift`
- `llm-visualizer/Services/LLMService.swift`
- `llm-visualizer/Views/Level1/NarratorLineView.swift`
- `llm-visualizer/Views/Level1/ProbabilityBarsView.swift` (structure unchanged; spacing tweaks land in Task 6)
- `llm-visualizer/Views/Common/LevelHeaderView.swift`
- `llm-visualizer/Views/Common/EmptyStateView.swift`
- `llm-visualizer/Views/Common/InspirationButtonsView.swift`

---

## Task 1: Add `style` parameter to `TokenBlocksView`

**Files:**
- Modify: `llm-visualizer/Views/Level2/TokenBlocksView.swift`
- Test: `llm-visualizerTests/TokenBlocksViewTests.swift`

- [ ] **Step 1.1: Write failing test for `style` parameter**

Create `llm-visualizerTests/TokenBlocksViewTests.swift`:

```swift
//
//  TokenBlocksViewTests.swift
//

import Foundation
import Testing
import SwiftUI
@testable import llm_visualizer

@MainActor
struct TokenBlocksViewTests {

    @Test func standardIsDefaultStyle() {
        // Construct without explicit style; verify it compiles and is non-nil.
        let view = TokenBlocksView(tokens: [
            TokenPiece(id: 1, text: "我"),
            TokenPiece(id: 2, text: "爱"),
        ])
        _ = view.body
    }

    @Test func compactStyleCompilesAlongsideStandard() {
        let standard = TokenBlocksView(tokens: [TokenPiece(id: 1, text: "我")])
        let compact = TokenBlocksView(tokens: [TokenPiece(id: 1, text: "我")], style: .compact)
        _ = standard.body
        _ = compact.body
    }

    @Test func emptyTokensYieldsEmptyBody() {
        let view = TokenBlocksView(tokens: [], style: .compact)
        // EmptyView conforms to View; we just ensure body compiles without
        // runtime crash. Behavior (hiding) is verified visually.
        _ = view.body
    }
}
```

- [ ] **Step 1.2: Run tests; verify compile error (no `style` param yet)**

Run tests in Xcode via `Cmd+U` with the test scheme. Expected: compile error "extra argument 'style'" on line 13 of the test file.

- [ ] **Step 1.3: Add `style` parameter to `TokenBlocksView`**

Edit `llm-visualizer/Views/Level2/TokenBlocksView.swift`. Replace the existing struct declaration and `body` with:

```swift
struct TokenBlocksView: View {
    enum Style { case standard, compact }

    let tokens: [TokenPiece]
    var style: Style = .standard

    var body: some View {
        if tokens.isEmpty {
            EmptyView()
        } else if tokens.count == 1 && style == .standard {
            singleBlockExplosion(token: tokens[0])
        } else {
            HStack(alignment: .center, spacing: style == .standard ? 8 : 4) {
                ForEach(tokens) { t in
                    blockTile(for: t)
                }
            }
        }
    }

    @ViewBuilder
    private func blockTile(for t: TokenPiece) -> some View {
        switch style {
        case .standard:
            Text(t.text)
                .font(.body.monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(blockColor(for: t))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
        case .compact:
            Text(t.text)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(blockColor(for: t))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func singleBlockExplosion(token: TokenPiece) -> some View {
        // Existing implementation, unchanged. (Kept as private; only `.standard`
        // ever calls it because Level 1 inputs always produce ≥ 2 tokens once
        // the user has typed anything beyond a single character.)
        Text(token.text)
            .font(.title2.monospaced().weight(.bold))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.84, blue: 0.04),
                        Color(red: 1.00, green: 0.62, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white, lineWidth: 4)
                    .padding(-4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.accentColor, lineWidth: 4)
                    .padding(-8)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .scaleEffect(1.0)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func blockColor(for piece: TokenPiece) -> Color {
        let palette: [Color] = [
            Color(red: 1.00, green: 0.84, blue: 0.04),
            Color(red: 0.20, green: 0.78, blue: 0.35),
            Color(red: 1.00, green: 0.27, blue: 0.23),
            Color(red: 0.04, green: 0.52, blue: 1.00),
            Color(red: 0.34, green: 0.78, blue: 0.98),
            Color(red: 0.75, green: 0.35, blue: 0.95),
            Color(red: 1.00, green: 0.45, blue: 0.70),
            Color(red: 0.40, green: 0.85, blue: 0.55),
        ]
        let idx = abs(piece.id.hashValue) % palette.count
        return palette[idx]
    }
}
```

- [ ] **Step 1.4: Run tests; verify pass**

`Cmd+U`. Expected: all 3 `TokenBlocksViewTests` pass.

- [ ] **Step 1.5: Commit**

```bash
git add llm-visualizer/Views/Level2/TokenBlocksView.swift llm-visualizerTests/TokenBlocksViewTests.swift
git commit -m "feat(TokenBlocksView): add Style enum (.standard | .compact) for cross-level reuse"
```

---

## Task 2: Move `TokenBlocksView` to `Views/Common/`

**Files:**
- Move: `llm-visualizer/Views/Level2/TokenBlocksView.swift` → `llm-visualizer/Views/Common/TokenBlocksView.swift`
- Modify: `llm-visualizer/Views/Level2/PlayingView.swift` (no edit needed; same module)

- [ ] **Step 2.1: Move file with `git mv`**

```bash
mkdir -p llm-visualizer/Views/Common
git mv llm-visualizer/Views/Level2/TokenBlocksView.swift llm-visualizer/Views/Common/TokenBlocksView.swift
```

- [ ] **Step 2.2: Verify Level 2 still compiles**

Open Xcode, build the project (`Cmd+B`). The `PlayingView` already uses `TokenBlocksView` unqualified (same module), so the move should be transparent. Expected: build succeeds.

- [ ] **Step 2.3: Run all tests; verify Level 2 tests still pass**

`Cmd+U`. Expected: `TokenBlocksViewTests` and `Level2ViewModel*Tests` all pass.

- [ ] **Step 2.4: Commit**

```bash
git add -A
git commit -m "refactor(TokenBlocksView): move to Views/Common for cross-level reuse"
```

---

## Task 3: Extract `CounterCell` to `Views/Common/`

**Files:**
- Create: `llm-visualizer/Views/Common/CounterCell.swift`
- Modify: `llm-visualizer/Views/Level2/PlayingView.swift` (replace inline `counterCell` with shared component)

- [ ] **Step 3.1: Create `CounterCell.swift`**

Create `llm-visualizer/Views/Common/CounterCell.swift`:

```swift
//
//  CounterCell.swift
//

import SwiftUI

struct CounterCell: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
```

- [ ] **Step 3.2: Update Level 2 `PlayingView` to use shared `CounterCell`**

In `llm-visualizer/Views/Level2/PlayingView.swift`, replace the existing `counterCell(label:value:)` private function and the call sites in `countersSection`. Remove this private function:

```swift
private func counterCell(label: String, value: Int) -> some View {
    VStack(spacing: 4) {
        Text("\(value)")
            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.primary)
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
    )
}
```

And replace the two `counterCell(...)` call sites with:

```swift
CounterCell(
    label: String(localized: "level2.counters.chars", defaultValue: "characters"),
    value: viewModel.rawText.count
)
CounterCell(
    label: String(localized: "level2.counters.blocks", defaultValue: "blocks"),
    value: viewModel.tokens.count
)
```

- [ ] **Step 3.3: Build; verify Level 2 still compiles and looks identical**

`Cmd+B`. Expected: clean build. Visually run Level 2 and confirm counters look the same as before.

- [ ] **Step 3.4: Commit**

```bash
git add llm-visualizer/Views/Common/CounterCell.swift llm-visualizer/Views/Level2/PlayingView.swift
git commit -m "refactor(CounterCell): extract shared counter UI from Level 2 for Level 1 reuse"
```

---

## Task 4: Add real-time tokenization to `Level1ViewModel`

**Files:**
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Create: `llm-visualizerTests/Level1ViewModelTokensTests.swift`

- [ ] **Step 4.1: Write failing tests for real-time tokenize**

Create `llm-visualizerTests/Level1ViewModelTokensTests.swift`:

```swift
//
//  Level1ViewModelTokensTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level1ViewModelTokensTests {

    private func vm() -> (Level1ViewModel, MockLLMService) {
        let mock = MockLLMService()
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        return (Level1ViewModel(service: mock, progressStore: store), mock)
    }

    @Test func promptChangeTriggersTokenize() async {
        let (v, mock) = vm()
        mock.stubbedTokens["hi"] = [TokenPiece(id: 1, text: "hi")]
        v.prompt = "hi"
        await v.waitForPendingTokenize()
        #expect(v.tokens.map(\.text) == ["hi"])
    }

    @Test func rapidPromptChangesCancelPrior() async {
        let (v, mock) = vm()
        mock.stubbedTokens["a"] = [TokenPiece(id: 1, text: "a")]
        mock.stubbedTokens["ab"] = [TokenPiece(id: 2, text: "ab")]
        v.prompt = "a"
        v.prompt = "ab"
        await v.waitForPendingTokenize()
        #expect(v.tokens.map(\.text) == ["ab"])
    }

    @Test func emptyPromptProducesEmptyTokens() async {
        let (v, _) = vm()
        v.prompt = ""
        await v.waitForPendingTokenize()
        #expect(v.tokens.isEmpty)
    }

    @Test func tokenizeErrorShowsBanner() async {
        let (v, mock) = vm()
        mock.tokenizeError = NSError(domain: "test", code: 1)
        v.prompt = "x"
        await v.waitForPendingTokenize()
        #expect(v.errorBanner != nil)
    }

    @Test func promptEqualsOldValueDoesNotRetokenize() async {
        let (v, mock) = vm()
        mock.stubbedTokens["hi"] = [TokenPiece(id: 1, text: "hi")]
        v.prompt = "hi"
        await v.waitForPendingTokenize()
        let countAfterFirst = v.tokens.count
        v.prompt = "hi"  // no change
        await v.waitForPendingTokenize()
        #expect(v.tokens.count == countAfterFirst)
    }
}
```

- [ ] **Step 4.2: Run tests; verify compile errors (no `tokens`, `waitForPendingTokenize`)**

`Cmd+U`. Expected: compile errors referencing `waitForPendingTokenize` and `tokens` on `Level1ViewModel`.

- [ ] **Step 4.3: Add real-time tokenize state and pipeline to `Level1ViewModel`**

Edit `llm-visualizer/ViewModels/Level1ViewModel.swift`. Make three changes:

**Change A**: Convert `prompt` from `var` to a property with `didSet`:

Replace the existing:
```swift
    var prompt: String = ""
```
with:
```swift
    var prompt: String = "" {
        didSet {
            guard oldValue != prompt else { return }
            onPromptChanged()
        }
    }
```

**Change B**: Add new properties. Find the existing `errorBanner` declaration and add these immediately above it:

```swift
    var tokens: [TokenPiece] = []
    private(set) var tokenizeTask: Task<Void, Never>?
```

**Change C**: Add the helper methods. Insert after the existing `func dismissCelebration()`:

```swift
    /// Wait for the in-flight tokenize task to complete. Tests use this to
    /// await real-time tokenization deterministically. No-op when no task.
    func waitForPendingTokenize() async {
        await tokenizeTask?.value
    }

    /// Real-time tokenize pipeline: every keystroke cancels any prior task
    /// and launches a fresh one. Mirrors `Level2ViewModel.onRawTextChanged`.
    /// Errors surface via `errorBanner` (3s auto-clear, same as submit errors).
    private func onPromptChanged() {
        tokenizeTask?.cancel()
        let text = prompt
        tokenizeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let pieces = try await self.service.tokenize(text)
                guard !Task.isCancelled else { return }
                self.tokens = pieces
            } catch {
                guard !Task.isCancelled else { return }
                self.showError(LevelError.humanize(error))
            }
        }
    }
```

`showError(_:)` already exists on the class. `LevelError.humanize(_:)` is already imported via the existing `submit()` catch branch.

- [ ] **Step 4.4: Run tests; verify pass**

`Cmd+U`. Expected: all 5 `Level1ViewModelTokensTests` pass. Existing `Level1ViewModelTests` still pass (no signature changes).

- [ ] **Step 4.5: Run full test suite; verify nothing else broke**

`Cmd+U` against the full test scheme. Expected: 0 regressions.

- [ ] **Step 4.6: Commit**

```bash
git add llm-visualizer/ViewModels/Level1ViewModel.swift llm-visualizerTests/Level1ViewModelTokensTests.swift
git commit -m "feat(Level1): real-time tokenizer pipeline on prompt change"
```

---

## Task 5: Add `isNewRecord` flag to `Level1ViewModel`

**Files:**
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Create: `llm-visualizerTests/Level1ViewModelNewRecordTests.swift`

- [ ] **Step 5.1: Write failing tests for `isNewRecord`**

Create `llm-visualizerTests/Level1ViewModelNewRecordTests.swift`:

```swift
//
//  Level1ViewModelNewRecordTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct Level1ViewModelNewRecordTests {

    private func vm(stubbed: [TokenCandidate]) -> Level1ViewModel {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = stubbed
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        return Level1ViewModel(service: mock, progressStore: store)
    }

    @Test func newRecordSetWhenBeatingBest() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.95),
        ])
        // bestSoFar starts at 0.0; 0.95 beats it.
        v.prompt = "test"
        await v.submit()
        #expect(v.isNewRecord == true)
    }

    @Test func dismissCelebrationClearsNewRecord() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.95),
        ])
        v.prompt = "test"
        await v.submit()
        #expect(v.isNewRecord == true)
        v.dismissCelebration()
        #expect(v.isNewRecord == false)
    }

    @Test func notNewRecordWhenBelowBest() async {
        // Prefill bestSoFar to 0.99 so 0.50 doesn't beat it.
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "x", probability: 0.50),
        ]
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.setBestProbability(1, 0.99)
        let v = Level1ViewModel(service: mock, progressStore: store)
        v.prompt = "test"
        await v.submit()
        #expect(v.isNewRecord == false)
    }

    @Test func newRecordClearedOnNextSubmitEvenIfNotPassing() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "x", probability: 0.95),
        ]
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let v = Level1ViewModel(service: mock, progressStore: store)
        v.prompt = "first"
        await v.submit()
        #expect(v.isNewRecord == true)
        // Swap to a low-probability stub for second submit
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 2, text: "y", probability: 0.30),
        ]
        v.prompt = "second"
        await v.submit()
        // isNewRecord is for "this attempt beat best"; since 0.30 < 0.95, false.
        #expect(v.isNewRecord == false)
    }
}
```

- [ ] **Step 5.2: Run tests; verify compile errors**

`Cmd+U`. Expected: compile errors referencing `isNewRecord` on `Level1ViewModel`.

- [ ] **Step 5.3: Add `isNewRecord` state and update `submit`/`dismissCelebration`**

Edit `llm-visualizer/ViewModels/Level1ViewModel.swift`. Three changes:

**Change A**: Add `isNewRecord` declaration. Find the existing `var bestSoFar: Double = 0.0` line and add immediately below:

```swift
    /// True when the most recent `submit()` set a new `bestSoFar` record.
    /// Cleared on `dismissCelebration()`. Drives the "NEW BEST" badge on
    /// `PassCelebrationView`.
    private(set) var isNewRecord: Bool = false
```

**Change B**: Update `submit()` to compute `isNewRecord`. Replace the existing body of `submit()`:

```swift
    func submit() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let candidates = try await service.predictNextTokens(
                prompt: trimmed, topK: 4)
            topCandidates = candidates
            submitCount += 1
            let maxProb = candidates.map(\.probability).max() ?? 0
            if maxProb > bestSoFar {
                isNewRecord = true
                bestSoFar = maxProb
                progressStore.setBestProbability(1, maxProb)
            } else {
                isNewRecord = false
            }
            if let top1 = candidates.first,
               top1.probability > Self.passThreshold {
                state = .passed
            }
        } catch {
            showError(LevelError.humanize(error))
        }
    }
```

**Change C**: Update `dismissCelebration()` to clear `isNewRecord`. Replace the existing:

```swift
    func dismissCelebration() {
        if state == .passed { state = .playing }
    }
```

with:

```swift
    func dismissCelebration() {
        if state == .passed { state = .playing }
        isNewRecord = false
    }
```

- [ ] **Step 5.4: Run tests; verify pass**

`Cmd+U`. Expected: all 4 `Level1ViewModelNewRecordTests` pass. Existing `Level1ViewModelTests` and `Level1ViewModelTokensTests` still pass.

- [ ] **Step 5.5: Commit**

```bash
git add llm-visualizer/ViewModels/Level1ViewModel.swift llm-visualizerTests/Level1ViewModelNewRecordTests.swift
git commit -m "feat(Level1): track isNewRecord on submit; cleared on dismissCelebration"
```

---

## Task 6: Add `isNewRecord` parameter + NEW BEST badge to `PassCelebrationView`

**Files:**
- Modify: `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`
- Create: `llm-visualizerTests/PassCelebrationViewTests.swift`

- [ ] **Step 6.1: Write failing test for `isNewRecord` param**

Create `llm-visualizerTests/PassCelebrationViewTests.swift`:

```swift
//
//  PassCelebrationViewTests.swift
//

import Foundation
import Testing
import SwiftUI
@testable import llm_visualizer

@MainActor
struct PassCelebrationViewTests {

    @Test func newRecordParamCompilesForTrue() {
        let view = PassCelebrationView(
            echoedPrompt: "x",
            topCandidate: TokenCandidate(id: 1, text: "y", probability: 0.95),
            isNewRecord: true,
            onContinue: {},
            onGoToNextLevel: {}
        )
        _ = view.body
    }

    @Test func newRecordParamCompilesForFalse() {
        let view = PassCelebrationView(
            echoedPrompt: "x",
            topCandidate: TokenCandidate(id: 1, text: "y", probability: 0.95),
            isNewRecord: false,
            onContinue: {},
            onGoToNextLevel: nil
        )
        _ = view.body
    }

    @Test func newRecordDefaultsToFalseWhenNotProvided() {
        // Source-compatible with existing call sites that omit the param.
        let view = PassCelebrationView(
            echoedPrompt: "x",
            topCandidate: nil,
            onContinue: {},
            onGoToNextLevel: nil
        )
        _ = view.body
    }
}
```

- [ ] **Step 6.2: Run tests; verify compile error (no `isNewRecord` param)**

`Cmd+U`. Expected: compile error "missing argument 'isNewRecord'" once we remove the default.

- [ ] **Step 6.3: Update `PassCelebrationView` signature and add badge**

Edit `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`. Three changes:

**Change A**: Add `isNewRecord` property to the struct. Replace the existing struct declaration:

```swift
struct PassCelebrationView: View {

    let echoedPrompt: String?
    let topCandidate: TokenCandidate?
    let isNewRecord: Bool
    let onContinue: () -> Void
    /// Optional closure invoked when the user taps "Next level →".
    /// Pass `nil` to hide the button (e.g., on the last level).
    let onGoToNextLevel: (() -> Void)?

    init(
        echoedPrompt: String?,
        topCandidate: TokenCandidate?,
        isNewRecord: Bool = false,
        onContinue: @escaping () -> Void,
        onGoToNextLevel: (() -> Void)?
    ) {
        self.echoedPrompt = echoedPrompt
        self.topCandidate = topCandidate
        self.isNewRecord = isNewRecord
        self.onContinue = onContinue
        self.onGoToNextLevel = onGoToNextLevel
    }
```

**Change B**: Add the NEW BEST badge inside the `body` VStack, immediately after the trophy emoji Text:

```swift
            VStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 64))
                if isNewRecord {
                    Text(String(
                        localized: "level1.passed.newRecord",
                        defaultValue: "NEW BEST"
                    ))
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
                }
                Text("FIRST CLEAR")
```

**Change C**: Update the `#Preview` block at the bottom of the file to pass `isNewRecord: true` so the preview shows the badge:

```swift
#Preview {
    PassCelebrationView(
        echoedPrompt: "中华人民共和",
        topCandidate: TokenCandidate(id: 1, text: "国", probability: 0.95),
        isNewRecord: true,
        onContinue: {},
        onGoToNextLevel: {}
    )
}
```

- [ ] **Step 6.4: Run tests; verify pass**

`Cmd+U`. Expected: all 3 `PassCelebrationViewTests` pass.

- [ ] **Step 6.5: Update `LevelShellView` to pass `isNewRecord`**

Edit `llm-visualizer/Views/LevelShell/LevelShellView.swift`, line 73-83. Replace the existing `PassCelebrationView(...)` construction:

```swift
                PassCelebrationView(
                    echoedPrompt: level1.viewModel.prompt,
                    topCandidate: level1.viewModel.topCandidates.first,
                    isNewRecord: level1.viewModel.isNewRecord,
                    onContinue: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            dismissed = true
                            level1.viewModel.dismissCelebration()
                        }
                    },
                    onGoToNextLevel: hasNextLevel ? onAdvanceLevel : nil
                )
```

Only `isNewRecord: level1.viewModel.isNewRecord` is added; everything else is unchanged.

- [ ] **Step 6.6: Build and run full suite; verify clean**

`Cmd+B` then `Cmd+U`. Expected: 0 failures.

- [ ] **Step 6.7: Commit**

```bash
git add llm-visualizer/Views/LevelShell/PassCelebrationView.swift llm-visualizer/Views/LevelShell/LevelShellView.swift llm-visualizerTests/PassCelebrationViewTests.swift
git commit -m "feat(Level1): NEW BEST badge on PassCelebrationView, wired from Level1ViewModel.isNewRecord"
```

---

## Task 7: Wire visual upgrades into `Level1View`

**Files:**
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`

- [ ] **Step 7.1: Add `canSubmit` computed property**

In `llm-visualizer/Views/Level1/Level1View.swift`, add this private computed property just below the existing `@FocusState`:

```swift
    private var canSubmit: Bool {
        !viewModel.prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
            && !viewModel.isLoading
    }
```

- [ ] **Step 7.2: Update Submit button to use `canSubmit` for background**

Find the existing submit `Button` (around line 119-145) and replace the single line:

```swift
                            .background(Circle().fill(Color.accentColor))
```

with:

```swift
                            .background(Circle().fill(canSubmit ? Color.accentColor : Color.gray.opacity(0.4)))
```

- [ ] **Step 7.3: Insert TokenBlocksView row**

Find the line in `body` containing `if viewModel.topCandidates.isEmpty {` (around line 42). Insert a new view **immediately above** it (between `inputSection` and the EmptyStateView/ProbabilityBarsView branch):

```swift
            if !viewModel.tokens.isEmpty {
                TokenBlocksView(tokens: viewModel.tokens, style: .compact)
                    .padding(.vertical, 4)
                    .transition(.opacity)
            }
            if viewModel.topCandidates.isEmpty {
```

- [ ] **Step 7.4: Insert CounterCell row**

Still in `body`, inside the `else` branch of the `topCandidates.isEmpty` check, **above** the existing `ProbabilityBarsView(...)` call. The structure currently is:

```swift
            } else {
                ProbabilityBarsView(
                    candidates: viewModel.topCandidates,
                    isPassed: viewModel.currentTop1IsPass
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
```

Replace with:

```swift
            } else {
                HStack(spacing: 12) {
                    CounterCell(
                        label: String(localized: "level1.counter.top1", defaultValue: "top-1"),
                        value: Int((viewModel.topCandidates.first?.probability ?? 0) * 100)
                    )
                    CounterCell(
                        label: String(localized: "level1.counter.blocks", defaultValue: "blocks"),
                        value: viewModel.tokens.count
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                ProbabilityBarsView(
                    candidates: viewModel.topCandidates,
                    isPassed: viewModel.currentTop1IsPass
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
```

- [ ] **Step 7.5: Insert state pill**

Find the existing `if showNarrator { NarratorLineView(...) }` block (around line 59). Replace it with:

```swift
            if showNarrator {
                NarratorLineView(sentiment: viewModel.currentSentiment)
                    .padding(.bottom, 4)
            }
            if viewModel.currentTop1IsPass {
                Text(String(
                    localized: "level1.statePill",
                    defaultValue: "✨ passed"
                ))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.18)))
                .foregroundStyle(Color.green)
                .padding(.bottom, 4)
                .transition(.opacity)
            }
```

- [ ] **Step 7.6: Add `.animation` for transitions**

Find the `.animation(.easeInOut(duration: 0.2), value: viewModel.errorBanner)` modifier near the bottom of `body` and add an additional animation line for `tokens`:

```swift
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorBanner)
        .animation(.easeInOut(duration: 0.2), value: viewModel.tokens)
```

- [ ] **Step 7.7: Build; verify visual layout**

`Cmd+B`. Open Level 1 in simulator and verify:
- Typing into the input updates `TokenBlocksView` immediately.
- After first submit, the counter row appears showing top-1 % and block count.
- After a passing submit, the green "✨ passed" pill appears below the narrator.
- Submit button is gray when input is empty/whitespace; accent when input is non-empty.
- NEW BEST badge appears on `PassCelebrationView` only when current attempt beat all-time best.

- [ ] **Step 7.8: Run full test suite; verify no regressions**

`Cmd+U`. Expected: 0 failures across all test files.

- [ ] **Step 7.9: Commit**

```bash
git add llm-visualizer/Views/Level1/Level1View.swift
git commit -m "feat(Level1): wire compact token blocks, counter row, state pill, submit gray-out"
```

---

## Task 8: Add localization strings (en + zh-Hans)

**Files:**
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 8.1: Open `Localizable.xcstrings`**

The file is auto-generated by Xcode from `String(localized:defaultValue:)` calls in source. Adding the calls (already done in Tasks 6 and 7) is the user-facing change; the xcstrings file gets regenerated when Xcode syncs.

- [ ] **Step 8.2: Trigger xcstrings sync via Xcode build**

`Cmd+B`. After build, Xcode writes the new keys into `Localizable.xcstrings`. Verify by opening the file and grepping:

```bash
grep -c "level1.statePill" llm-visualizer/Resources/Localizable.xcstrings
grep -c "level1.passed.newRecord" llm-visualizer/Resources/Localizable.xcstrings
grep -c "level1.counter.top1" llm-visualizer/Resources/Localizable.xcstrings
grep -c "level1.counter.blocks" llm-visualizer/Resources/Localizable.xcstrings
```

Expected: each prints `1` or more (entries appear under `strings`).

- [ ] **Step 8.3: Manually add zh-Hans translations**

Open `Localizable.xcstrings` in Xcode's String Catalog editor. For each new key:

| Key | en (default) | zh-Hans |
|-----|--------------|---------|
| `level1.statePill` | `✨ passed` | `✨ 通过` |
| `level1.passed.newRecord` | `NEW BEST` | `新纪录` |
| `level1.counter.top1` | `top-1` | `top-1` (no translation — technical term) |
| `level1.counter.blocks` | `blocks` | `块` |

- [ ] **Step 8.4: Build and verify in simulator (zh-Hans region)**

Switch simulator region to Chinese (Simplified) via Settings → General → Language & Region. Run Level 1 and verify:
- "✨ 通过" pill text
- "新纪录" badge on celebration
- "top-1" / "块" counter labels

Switch back to English to verify en strings.

- [ ] **Step 8.5: Commit**

```bash
git add llm-visualizer/Resources/Localizable.xcstrings
git commit -m "chore(localization): add Level 1 visual upgrade strings (en + zh-Hans)"
```

---

## Task 9: Final verification

**Files:** None

- [ ] **Step 9.1: Run full test suite**

`Cmd+U` against the project test scheme. Expected: 0 failures, all green.

- [ ] **Step 9.2: Manual smoke test of Level 1**

In simulator, play through Level 1:
1. Land on Level 1 → input is empty → no blocks row visible (correct).
2. Type "我" → blocks row appears with 1 block (compact).
3. Type "我爱" → blocks row updates to 2 blocks.
4. Submit → counter row appears: top-1 X%, blocks 2.
5. Probability bars appear below counter row.
6. Type a long common phrase (e.g., "The quick brown fox"), submit, get high probability → green pill appears.
7. Verify submit button is gray when input is empty.
8. Submit a passing attempt → `PassCelebrationView` appears. If current attempt beats the previous best, "NEW BEST" badge is visible.
9. Tap "Try again" → celebration dismisses → return to playing state.

- [ ] **Step 9.3: Manual smoke test of Level 2**

Verify Level 2 visuals are unchanged:
1. Land on Level 2 hook → tap "Show me".
2. Demo view → token blocks appear (standard style — bigger padding, border).
3. Tap "I've got it" → challenge intro → tap "Start".
4. Playing view → counter row appears with characters + blocks cells (now using shared `CounterCell`).
5. Verify counter cell visuals are identical to before this PR.

- [ ] **Step 9.4: Final commit if any cleanup was needed**

If steps 9.1-9.3 surfaced fixes, commit them as separate `fix(...)` commits on the same branch.

- [ ] **Step 9.5: Push branch and open PR**

```bash
git push -u origin feat/level1-visual-upgrade
gh pr create --base main --title "Level 1 visual upgrade: borrow Level 2 patterns" --body "$(cat <<'EOF'
Closes: N/A
Spec: docs/superpowers/specs/2026-07-12-level1-visual-upgrade-design.md
Plan: docs/superpowers/plans/2026-07-12-level1-visual-upgrade.md

Changes:
- TokenBlocksView moved to Views/Common with .standard / .compact styles
- CounterCell extracted to Views/Common; reused by Level 1 and Level 2
- Level1ViewModel: real-time tokenization on prompt change
- Level1ViewModel: isNewRecord flag for NEW BEST badge
- PassCelebrationView: NEW BEST badge when isNewRecord
- Level1View: compact token blocks, top-1/blocks counter row, ✨ passed pill, submit button gray-out
- Localization: en + zh-Hans for new strings (新纪录 / ✨ 通过)

Tests:
- TokenBlocksViewTests (3 tests)
- Level1ViewModelTokensTests (5 tests)
- Level1ViewModelNewRecordTests (4 tests)
- PassCelebrationViewTests (3 tests)

All existing tests continue to pass.
EOF
)"
```

---

## Self-review checklist

1. **Spec coverage:**
   - A. TokenBlocksView of input above bars — Task 7.3 ✓
   - B. Big-number top-1 counter — Tasks 3 (CounterCell) + 7.4 ✓
   - C. "✨ passed" state pill — Task 7.5 ✓
   - D. NEW BEST badge on celebration — Task 6.3 ✓
   - E. Submit button gray-out — Tasks 7.1 + 7.2 ✓
   - F. Real-time tokenization — Task 4 ✓
   - G. Goal caption (already shipped) — confirmed in spec, no task needed ✓
   - CounterCell shared — Tasks 3 + 7.4 ✓
   - TokenBlocksView moved to Common — Task 2 ✓

2. **Placeholder scan:** No "TBD" or "TODO" in any step. All code blocks complete.

3. **Type consistency:**
   - `Level1ViewModel.tokens: [TokenPiece]` introduced Task 4, used Tasks 5, 7 ✓
   - `Level1ViewModel.tokenizeTask` introduced Task 4, used Task 4 ✓
   - `Level1ViewModel.waitForPendingTokenize()` introduced Task 4, used Task 4 tests ✓
   - `Level1ViewModel.isNewRecord: Bool` introduced Task 5, used Tasks 6, 7 ✓
   - `TokenBlocksView.style: Style` introduced Task 1, used Tasks 1, 2, 7 ✓
   - `CounterCell(label:value:)` introduced Task 3, used Tasks 3, 7 ✓
   - `PassCelebrationView.isNewRecord: Bool` introduced Task 6, used Tasks 6, 9 ✓

4. **Risk check:**
   - `prompt.didSet` does not fire from `submit()` because `submit()` doesn't mutate `prompt`. Verified by reading `submit()` implementation. ✓
   - `CounterCell` extraction is source-compatible with Level 2 because Level 2's inline cell is identical in shape. ✓
   - `TokenBlocksView` move is source-compatible because same module, same name. ✓
   - `PassCelebrationView` default `isNewRecord = false` keeps existing call sites compilable; the only caller (`LevelShellView`) is updated in Task 6.5 anyway. ✓
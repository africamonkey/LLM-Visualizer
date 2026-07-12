# Level 1 Visual Upgrade — Design

**Date:** 2026-07-12
**Status:** Draft, awaiting user review
**Branch prefix:** `feat/level1-visual-upgrade`

## 1. Goal

Level 1 should borrow Level 2's visual and UX patterns where doing so reinforces the educational arc, without losing its own identity ("make AI guess the next word"). The biggest payoff is **showing the user's input as token blocks in real time**: when they enter Level 2, the "AI chops text into blocks" concept is already familiar because Level 1 made them see it.

Scope: 7 changes (A–G below). Excluded: hint system, star rating, full PassCelebrationView rewrite, language-tier thresholds.

## 2. Scope

### In scope

| ID | Pattern | Source (Level 2) |
|----|---------|-------------------|
| A | TokenBlocksView of input above the bars (real-time) | `Views/Level2/TokenBlocksView.swift` |
| B | Big-number top-1 probability counter (38pt rounded) | `Views/Level2/PlayingView.swift:131-145` |
| C | "✨ passed" state pill with opacity transition | `Views/Level2/PlayingView.swift:118-126` |
| D | NEW BEST badge on PassCelebrationView | `Views/Level2/PassedView.swift:19-31` |
| E | Submit button disabled-state gray fill | `Views/Level2/PlayingView.swift:81` |
| F | Real-time token count via in-progress tokenizer | `ViewModels/Level2ViewModel.swift:127-142` |
| G | Goal caption — **already shipped** | `Level1Session.swift:26-29`, `LevelHeaderView.swift:40-46` |

### Out of scope (deferred or rejected)

- **Hint system for Level 1.** Level 1 submits are model-inference-heavy; a hint banner would compete with the narrator sentiment line. Defer.
- **Stars for Level 1.** Level 1 has no star mechanic in the spec; adding one is a separate design.
- **Full PassCelebrationView rewrite.** We only add the NEW BEST badge (D). The summary card stays as-is.
- **Language-tier thresholds.** User explicitly cancelled this work earlier.

## 3. Design decisions

### A. TokenBlocksView of input

**Position:** Below the input row, above the probability bars. The visual order is:

```
[TextField] [Submit]
↓ token blocks (your sentence as blocks)
[Top-1 87% counter · N tokens counter]
[Probability bars]
[Narrator line / state pill]
```

**Component:** Move `Views/Level2/TokenBlocksView.swift` to `Views/Common/TokenBlocksView.swift` and add a `style` parameter:

```swift
struct TokenBlocksView: View {
    enum Style { case standard, compact }
    let tokens: [TokenPiece]
    var style: Style = .standard

    var body: some View {
        // ... existing logic, plus:
        //   - .standard: current Level 2 visuals (body monospaced, 12×8 padding, hairline border)
        //   - .compact: caption monospaced, 8×4 padding, no border, no shadow
        //   - singleBlockExplosion branch only renders in .standard (Level 1
        //     always has ≥ 2 tokens once it has any; if user manages a 1-token
        //     input we still use the compact HStack — explosion is a Level 2
        //     celebration affordance, not a general visual)
    }
}
```

Level 1 uses `.compact`. Level 2's existing call sites update to pass `.standard` explicitly (or leave default).

**Real-time data flow:** `Level1ViewModel` gets new state (see F) and exposes `tokens: [TokenPiece]`. `Level1View` renders `TokenBlocksView(tokens: viewModel.tokens, style: .compact)` whenever `!viewModel.tokens.isEmpty`.

### B. Big-number top-1 probability counter

**Position:** Below TokenBlocksView, above the probability bars. Sits in a row with the tokens counter (F) — see layout below.

**Visual:**

```swift
HStack(spacing: 12) {
    counterCell(label: "top-1", value: topPct)   // 38pt rounded monospaced
    counterCell(label: "blocks", value: tokens.count)  // same style
}
```

`topPct` is `Int((topCandidates.first?.probability ?? 0) * 100)` followed by `"%"`. Counter cells appear only when `topCandidates` is non-empty (i.e., after first submit).

Reuses the same counter cell styling as Level 2's `PlayingView.swift:130-145`. To avoid duplication, factor the cell into a `CounterCell` view in `Views/Common/`. Level 2 switches its existing inline cell to the shared component.

### C. "✨ passed" state pill

**Trigger:** `viewModel.currentTop1IsPass == true` — true after a submit whose top-1 probability exceeds `passThreshold`. Resets to false on next submit.

**Visual:**

```swift
HStack {
    Text("✨ passed")
        .font(.caption.weight(.bold))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.green.opacity(0.18)))
        .foregroundStyle(Color.green)
        .transition(.opacity)
}
```

**Position:** Below the narrator line. When `state == .playing`, the narrator still shows sentiment; the pill is independent. When `state == .passed`, the celebration overlay takes over the screen — the pill is irrelevant and naturally hidden.

**Localization key:** `level1.statePill` default `"✨ passed"`.

### D. NEW BEST badge on PassCelebrationView

**Where it lives:** Top of `PassCelebrationView.swift`, between the trophy emoji and the "FIRST CLEAR" caption. Mirrors Level 2's `PassedView.swift:19-31`.

**Data flow:**
1. `Level1ViewModel` gains `private(set) var isNewRecord: Bool = false`.
2. Inside `submit()`, after computing `maxProb`, set `isNewRecord = maxProb > bestSoFar` (and update `bestSoFar` as today).
3. `dismissCelebration()` clears it back to `false` so the badge doesn't linger into the next round.
4. `PassCelebrationView.init(...)` gains `let isNewRecord: Bool`.
5. `LevelShellView.swift:73` constructs it with `isNewRecord: level1.viewModel.isNewRecord`.

**Visual:**

```swift
if isNewRecord {
    Text("NEW BEST")
        .font(.caption.weight(.bold)).tracking(2)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color.accentColor))
        .foregroundStyle(.white)
}
```

**Localization key:** `level1.passed.newRecord` default `"NEW BEST"`.

### E. Submit button disabled-state gray fill

**Change:** Extract `canSubmit` computed property on `Level1View` (mirrors `PlayingView.swift:152-156`) and condition the button background:

```swift
.background(Circle().fill(canSubmit ? Color.accentColor : Color.gray.opacity(0.4)))
```

`canSubmit` is `!viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading`. (Today's button is already disabled when empty — we just weren't visually distinguishing it.)

The loading-state branch (the `ProgressView` inside the circle when `isLoading`) is unchanged.

### F. Real-time tokenization in Level 1

**New state on `Level1ViewModel`:**

```swift
var tokens: [TokenPiece] = []
private(set) var tokenizeTask: Task<Void, Never>?
```

**Wiring:** Add a `didSet` to `prompt`:

```swift
var prompt: String = "" {
    didSet {
        guard oldValue != prompt else { return }
        tokenizeTask?.cancel()
        tokenizeTask = Task { [weak self] in
            guard let self else { return }
            let text = self.prompt
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
}
```

This mirrors `Level2ViewModel.onRawTextChanged` (`Level2ViewModel.swift:127-142`). The duplication is acceptable per the brainstorm decision; a future Level 3 may motivate a shared mixin.

**Cleanup:** On `dismissCelebration()`, leave tokens alone (the prompt stays in the field). If we ever add a "clear" affordance, it should also clear tokens.

**Error handling:** Reuses `Level1ViewModel.showError(...)` → `errorBanner`. No new code path needed.

### G. Goal caption

`Level1Session.goalDescription = "Get Top-1 probability above 90%"` already exists and is rendered by `LevelHeaderView` (header strip above the level). **No code change.** Confirmed during brainstorm recon.

## 4. Component architecture

| Component | Before | After |
|-----------|--------|-------|
| `Views/Level2/TokenBlocksView.swift` | Owned by Level 2 | Moves to `Views/Common/TokenBlocksView.swift` with `style` param |
| `Views/Common/CounterCell.swift` | (new) | Extracted from Level 2's inline counter cell (`PlayingView.swift:130-145`) |
| `Views/Level2/PlayingView.swift` | Uses inline `counterCell` | Switches to `CounterCell` from Common |
| `Views/Level1/Level1View.swift` | Single counter row absent | Adds `TokenBlocksView(compact)` + `CounterCell` row + state pill |
| `ViewModels/Level1ViewModel.swift` | No tokenize state | Adds `tokens`, `tokenizeTask`, `isNewRecord` |
| `Views/LevelShell/PassCelebrationView.swift` | No NEW BEST | Adds `isNewRecord` param + badge |
| `Views/LevelShell/LevelShellView.swift` | Constructs celebration without record flag | Passes `level1.viewModel.isNewRecord` |

## 5. Files affected

### Modify

- `llm-visualizer/Views/Level1/Level1View.swift` — add blocks row, counter row, state pill; update submit button styling
- `llm-visualizer/Views/Level1/ProbabilityBarsView.swift` — no behavior change; may receive small spacing tweaks
- `llm-visualizer/ViewModels/Level1ViewModel.swift` — add `tokens`, `tokenizeTask`, `isNewRecord`, prompt `didSet`
- `llm-visualizer/Views/LevelShell/PassCelebrationView.swift` — add `isNewRecord: Bool` init param + badge
- `llm-visualizer/Views/LevelShell/LevelShellView.swift` — pass `isNewRecord` when constructing celebration
- `llm-visualizer/Views/Level2/PlayingView.swift` — switch inline counter cell to shared `CounterCell`
- `llm-visualizer/Resources/Localizable.xcstrings` — add `level1.statePill`, `level1.passed.newRecord`

### Move

- `llm-visualizer/Views/Level2/TokenBlocksView.swift` → `llm-visualizer/Views/Common/TokenBlocksView.swift` (with `style` parameter)

### Add

- `llm-visualizer/Views/Common/CounterCell.swift`
- `llm-visualizerTests/Level1ViewModelTokensTests.swift`
- `llm-visualizerTests/PassCelebrationViewTests.swift` (or extend existing snapshot tests if present)

### Unchanged

- `llm-visualizer/Models/Level1Session.swift`
- `llm-visualizer/Models/Levels.swift`
- `llm-visualizer/Models/LevelProgress.swift`
- `llm-visualizer/Services/LLMService.swift`
- `llm-visualizer/Views/Level1/NarratorLineView.swift`
- `llm-visualizer/Views/Common/LevelHeaderView.swift`
- `llm-visualizer/Views/Common/EmptyStateView.swift`
- `llm-visualizer/Views/Common/InspirationButtonsView.swift`
- All non-Level-1, non-`PassCelebrationView`, non-`TokenBlocksView` test files

## 6. Test plan

Following `test-driven-development` skill: tests are written first, then implementation.

### New tests — `Level1ViewModelTokensTests.swift`

```swift
@Test func promptChangeTriggersTokenize() async {
    let mock = MockLLMService()
    mock.stubbedTokens["hi"] = [TokenPiece(id: 1, text: "hi")]
    let vm = Level1ViewModel(service: mock)
    vm.prompt = "hi"
    await vm.waitForPendingTokenize()    // helper to await tokenizeTask
    #expect(vm.tokens.map(\.text) == ["hi"])
}

@Test func rapidPromptChangesCancelPrior() async {
    let mock = MockLLMService()
    mock.stubbedTokens["a"] = [TokenPiece(id: 1, text: "a")]
    mock.stubbedTokens["ab"] = [TokenPiece(id: 2, text: "ab")]
    let vm = Level1ViewModel(service: mock)
    vm.prompt = "a"
    vm.prompt = "ab"
    await vm.waitForPendingTokenize()
    #expect(vm.tokens.map(\.text) == ["ab"])
}

@Test func emptyPromptProducesEmptyTokens() async {
    let mock = MockLLMService()
    let vm = Level1ViewModel(service: mock)
    vm.prompt = ""
    await vm.waitForPendingTokenize()
    #expect(vm.tokens.isEmpty)
}

@Test func tokenizeErrorShowsBanner() async {
    let mock = MockLLMService()
    mock.tokenizeError = TestError.boom
    let vm = Level1ViewModel(service: mock)
    vm.prompt = "x"
    await vm.waitForPendingTokenize()
    #expect(vm.errorBanner != nil)
}
```

`waitForPendingTokenize()` lives in `Level1ViewModel` (mirroring `Level2ViewModel.waitForPendingTokenize` at `Level2ViewModel.swift:111-113`).

### New tests — `Level1ViewModelNewRecordTests.swift`

```swift
@Test func newRecordSetWhenBeatingBest() async {
    let mock = MockLLMService()
    mock.stubbedPredictTopK = [
        TokenCandidate(id: 1, text: "x", probability: 0.95)
    ]
    let vm = Level1ViewModel(service: mock)
    vm.prompt = "test"  // bestSoFar starts at 0
    await vm.submit()
    #expect(vm.isNewRecord == true)
    vm.dismissCelebration()
    #expect(vm.isNewRecord == false)
}

@Test func notNewRecordWhenBelowBest() async {
    // bestSoFar prefilled to 0.99 via custom ProgressStore init
    let store = ProgressStore(defaults: isolatedDefaults())
    store.setBestProbability(1, 0.99)
    let mock = MockLLMService()
    mock.stubbedPredictTopK = [
        TokenCandidate(id: 1, text: "x", probability: 0.50)
    ]
    let vm = Level1ViewModel(service: mock, progressStore: store)
    vm.prompt = "test"
    await vm.submit()
    #expect(vm.isNewRecord == false)
}
```

### New tests — `PassCelebrationViewTests.swift`

```swift
@Test func showsNewBestBadgeWhenFlagTrue() {
    // Render via ViewInspector or just verify the rendering tree shape
    // (snapshot test if ViewInspector is set up; otherwise skip in CI and
    // rely on visual review).
}

@Test func hidesNewBestBadgeWhenFlagFalse() { ... }
```

If the project doesn't already use ViewInspector for view tests, fall back to manual visual review (snapshot tests are out of scope for this PR).

### Extended tests — `Level1ViewModelTests.swift`

The existing test file remains valid; no test should be deleted. New tests above live in dedicated files so the existing file's scope stays tight.

## 7. Localization

| Key | en | zh-Hans | Notes |
|-----|----|---------|-------|
| `level1.statePill` | `✨ passed` | `✨ 通过` | Mirrors Level 2's `level2.counters.passed`. |
| `level1.passed.newRecord` | `NEW BEST` | `新纪录` | Mirrors Level 2's `level2.passed.newRecord`. User confirmed zh-Hans. |

Both zh-Hans translations ship in this PR alongside the en changes. The `Localizable.xcstrings` changes in the working tree (uncommitted) belong to the prior session; this PR will add a separate commit on the `Localizable.xcstrings` file.

## 8. Risks & open questions

### Risks

1. **Real-time tokenize latency.** Every keystroke triggers `service.tokenize(...)`. On the real model this is a CPU-bound tokenizer pass; on the mock it's instant. We don't add debouncing per the brainstorm decision. Risk: sluggish typing on older devices. **Mitigation:** test on a real iPhone in the simulator before merging; if laggy, revisit debouncing as a follow-up.

2. **Tokenizer load on first keystroke.** First tokenize call hits `LLMService.tokenize` → `ensureContainer()` → `loadModel()` if model isn't loaded. This is shared with Level 2 and is fine because `AppShellViewModel` preloads the model before any level renders.

3. **`prompt.didSet` and `submit()`.** `submit()` mutates `topCandidates` but not `prompt`, so the didSet won't fire from submit. Good — no infinite loop risk.

4. **NEW BEST badge and `state == .passed`.** A pass with `isNewRecord == false` still shows the celebration (badge hidden). A pass with `isNewRecord == true` shows both. This matches Level 2.

5. **`PassCelebrationView` API change is breaking.** `LevelShellView` is the only caller in the codebase (verified by grep). Single-point update, low risk.

6. **`TokenBlocksView` move is breaking for Level 2.** `PlayingView.swift:148` is the only consumer. The file moves and gains an optional `style` parameter (default `.standard`), so Level 2's call site doesn't have to change. But the import path does. Verified during recon.

### Open questions

1. **Should the counter row replace the existing EmptyStateView placeholder, or stack above it?** Current design: counters replace the placeholder when candidates exist. Need to confirm visually in simulator before finalizing spacing.

2. **`level1.statePill` emoji `✨` vs SF Symbol.** Level 2 uses emoji in the pill (`✨`). Matches by precedent, ship as-is. If the user wants SF Symbol, change later.

3. ~~**`level1.passed.newRecord` zh-Hans translation.**~~ **Resolved**: zh-Hans = `"新纪录"` (user confirmed). Ship in this PR.

## 9. Acceptance criteria

- Level 1 view shows the user's prompt as compact token blocks in real time, updated on every keystroke.
- Level 1 view shows a "top-1: 87%" + "blocks: 5" counter row whenever probability candidates are present.
- Level 1 view shows a green "✨ passed" pill when the current submission's top-1 exceeds 90%.
- Submit button visibly grays out when the input is empty or whitespace.
- When the user passes with a probability greater than their all-time best, the PassCelebrationView shows a "NEW BEST" badge.
- `TokenBlocksView` is moved to `Views/Common/` and used by both Level 1 (compact) and Level 2 (standard).
- All existing tests continue to pass.
- New tests in §6 pass.
- No regressions in Level 2 visuals.
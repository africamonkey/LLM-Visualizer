# Level 2 — It reads the world in blocks

**Date:** 2026-07-10 (draft)
**Status:** Draft (pending user review)
**Target:** iOS 17.0+, Swift 5.9+
**Replaces:** the current `Level2View` / `Level2Session` placeholders.

## 1. Goal

Teach the user one concept, hands-on:

> **AI doesn't read characters. It chops text into chunky building blocks called tokens — and the chunks it makes are bigger for things it's seen a thousand times, smaller for things it hasn't.**

The whole level is structured so the user **discives this by playing**, not by reading. The mechanics:

- The user types into a free-form text field.
- The app calls the real tokenizer and displays each token as a distinct, easy-to-count colored block.
- Two big counters ("characters" / "blocks") sit above the field and update in real time.
- Pass condition: **token count equals 1**. Star rating is awarded by how many characters the user managed to pack into that single block (★ = 3, ★★ = 5, ★★★ = ≥ 7).

Failure is the engine of learning: random garbage and rare strings get chopped into many blocks; common words often round-trip as a single block. The user stumbles into the rule just by trying.

### 1.1 What this slice is not

- It is not a tutorial about BPE, subword regularization, vocabulary size, or any other technical term. The metaphor is **building blocks (积木)** and stays a metaphor. The word "token" appears once on the first demo screen and is never repeated.
- It is not Level 3 (temperature / knob). The Level 3 tease hook is *in scope* (last step of this level), but Level 3 itself is not.
- It does not add a new visualization primitive (the existing `ProbabilityBarsView` and `PassCelebrationView` patterns are reused where they fit).
- It does not require a network connection. The `container.tokenizer.encode(text:)` call already runs on-device against the loaded Qwen3-0.6B model.

## 2. Scope

**In scope (this slice):**

- Five-step flow replacing the current 8-stage sketch: **hook → demo → challengeIntro → playing → passed**.
- Inline hint system inside `playing` (was step 5 in the original sketch).
- One combined `passed` view carrying summary + stars + Level 3 hook (was steps 6 + 7 + 8 in the original sketch).
- New `tokenize(_ text:)` method on `LLMServiceProtocol`, returning `[TokenPiece]`. `MockLLMService` stubs the same call.
- New `TokenPiece` struct (id + decoded text per token).
- `ProgressStore` extension with `bestCharacterCount(_ levelId:) / setBestCharacterCount(_ levelId:_:)` mirroring the existing `bestProbability` API.
- `LevelHeaderView` extension to display `bestSoFar` for either metric.
- `Level1HeaderView`'s `bestSoFar` accessor (`(Level1Session).viewModel.bestSoFar`) is generalized into a `LevelSession.bestSoFarKind` enum (probability / character count), with `Level1Session` and `Level2Session` each providing one. Pure refactor.
- Token-block visualization with equal-width blocks + a single "explosion" treatment when `tokens.count == 1`.
- Localization: all player-facing strings into `Localizable.xcstrings` (en + zh-Hans).
- TDD on data-layer state machines: `Level2ViewModel`, `ProgressStore` (extended methods), `LLMServiceProtocol.tokenize` mock contract.
- Star threshold calibration: a one-shot Swift CLI probe (`scripts/probe-tokenizer.swift`) that prints `(word, tokenCount, charCount)` for a candidate word bank at development time. Star thresholds and the staged hint 2 example word are constants in `Level2Constants.swift`, sourced from running this probe.

**Out of scope:**

- Level 3 itself (temp knob, sampling, etc.). The Level 3 hook button shows a brief "coming soon" toast on tap.
- "Why tokens exist" or model-architecture explanation. Single insight per level.
- New generic primitives in `Views/Common/`.
- Animation polish beyond the existing `easeInOut(0.2)` style already in `Level1View`.
- Localized tokens. The displayed token text comes from `tokenizer.decode(...)` and is in whatever script the tokenizer produces.

## 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AppRootView                          │
│      (level picked from LevelRegistry, see below)       │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │      LevelShellView              │
        │      Level2Session               │
        └──────────────┬───────────────────┘
                       │ .makeContentView()
                       ▼
        ┌──────────────────────────────────┐
        │      Level2FlowView              │
        │      Level2ViewModel             │
        │       .step                      │
        └──────────────┬───────────────────┘
                       │ switch viewModel.step
       ┌───────────────┼───────────────┬──────────────┐
       ▼               ▼               ▼              ▼
   HookView       DemoView     ChallengeIntroView   PlayingView ──► (PassedView)
                  (input row)                    │ (inline HintBanner)
                                                 │      │
                                                 │      │ attemptCount ≥ 10
                                                 │      └─► autofills example word
                                                 │
                                                 └─► on tokens.count == 1 → step = .passed

   PassedView contains three sections in one card:
     1. Summary card     "你用 1 块装下了 7 个字"
     2. Star display     ★★★ / ★★ / ★
     3. Bridge section   Level 3 teaser + [再去刷] / [Level 3]
```

### 3.1 Key invariants

- **Tokenization happens on every keystroke.** Debouncing is not added — Qwen3's BPE encoder runs in microseconds for short strings; the existing `container.perform { }` already serializes calls behind the model container.
- **All slice-visible tokenization goes through `LLMServiceProtocol.tokenize(_:)`** — no view or view model reaches into `ModelContext.tokenizer` directly. Mocks can stub per-text responses for TDD.
- **Five steps, not eight.** The original sketch had eight; this slice merges the failure-time hint into a banner inside `PlayingView` and merges the post-pass summary / stars / bridge into one `PassedView`. Trivially, step names map to the original stages 1:1 except that 5 → inline banner and 6/7/8 → one view.
- **`bestCharCount` is the metric for star display**, derived from `ProgressStore.bestCharacterCount(2)`. The level's "complete" flag flips on first pass (1 token), independent of which star rating was achieved.
- **The level can be re-played indefinitely after first pass** to chase higher stars. `LevelSession.isComplete` does not lock further input.

## 4. Files

### 4.1 To create

```
llm-visualizer/
├── Models/
│   ├── TokenPiece.swift                # struct TokenPiece { id, text }
│   └── Level2Constants.swift           # star thresholds + hint-2 example
├── ViewModels/
│   └── Level2ViewModel.swift           # @MainActor @Observable, Step enum
└── Views/
    └── Level2/
        ├── Level2FlowView.swift        # switches body on viewModel.step
        ├── HookView.swift              # stage 1: curiosity bait + “带我看看”
        ├── DemoView.swift              # stage 2: free input + token viz reveal
        ├── ChallengeIntroView.swift    # stage 3: states the goal
        ├── PlayingView.swift           # stage 4: input + counters + token viz
        │                                # + inline HintBanner
        ├── TokenBlocksView.swift       # colored-block layout (equal-width,
        │                                # explosion on tokens.count == 1)
        ├── PassedView.swift            # stage 5: summary + stars + bridge
        └── HintBanner.swift            # tiered banner shown inside PlayingView

scripts/
└── probe-tokenizer.swift               # one-shot CLI to calibrate star thresholds

llm-visualizerTests/
├── Level2ViewModelTests.swift          # step transitions, pass detection,
│                                        # hint-tier escalation, attempt reset
└── ProgressStoreCharacterCountTests.swift  # bestCharacterCount extension
```

### 4.2 To delete

None. The current `Level2View.swift` is overwritten by `PlayingView` (or stays as a shell and is no longer `makeContentView`'d; the actual replacement is `Level2FlowView`).

### 4.3 To modify

- `llm-visualizer/Models/Level2Session.swift` — full rewrite. Owns a `Level2ViewModel`, routes `makeContentView` to `Level2FlowView(viewModel: session.viewModel)`. Implements `evaluate()`: on first pass flips `isComplete` and calls `progressStore.setBestCharacterCount`.
- `llm-visualizer/Services/LLMService.swift` — add `tokenize(_ text: String) async throws -> [TokenPiece]` to `LLMServiceProtocol`. Concrete impl in `LLMService` (encoder call + per-id decode). `MockLLMService` stubs it.
- `llm-visualizer/Models/LevelProgress.swift` — add `bestCharacterCount(_ levelId: Int) -> Int` and `setBestCharacterCount(_ levelId: Int, _ value: Int)` symmetric with `bestProbability`. Persisted under a new defaults key (`"llmviz.bestCharacterCounts"`).
- `llm-visualizer/Views/LevelShell/LevelShellView.swift` — generalize the `bestSoFar` accessor. Today it down-casts to `Level1Session`; switch to a virtual-ish `var bestSoFarKind: LevelSession.BestSoFarKind { get }` + a switch in `LevelHeaderView`. (`Level1Session` reports `.probability`, `Level2Session` reports `.characterCount`.)
- `llm-visualizer/Resources/Localizable.xcstrings` — add every new player-facing string in en + zh-Hans (see §9).

## 5. Components

### 5.1 `TokenPiece`

```swift
struct TokenPiece: Sendable, Equatable, Hashable, Identifiable {
    let id: Int          // tokenizer vocabulary id
    let text: String     // tokenizer.decode(tokens: [id], skipSpecialTokens: false)
}
```

**No unit test.** Pure data.

`charCount` is **not** stored on `TokenPiece`. The view layer derives `text.count` (Swift grapheme cluster count, per UI definition) when it needs the per-block character count for a star display. Storing it would be a denormalization that drifts from `text.count` whenever the tokenizer returns a chunk whose decoded string contains emoji or combining characters.

### 5.2 `LLMServiceProtocol.tokenize(_:)`

```swift
protocol LLMServiceProtocol: Sendable {
    @MainActor
    func loadModel() async throws -> ModelContainer           // existing
    @MainActor
    func generate(...) async throws -> AsyncStream<Generation> // existing
    @MainActor
    func predictNextTokens(...) async throws -> [TokenCandidate] // existing

    // new
    @MainActor
    func tokenize(_ text: String) async throws -> [TokenPiece]
}
```

Real impl:

```swift
@MainActor
func tokenize(_ text: String) async throws -> [TokenPiece] {
    if text.isEmpty { return [] }
    let container = try await ensureContainer()
    return try await container.perform { context in
        let ids = try context.tokenizer.encode(text: text)
        let tokenizer = context.tokenizer
        return ids.map { id in
            TokenPiece(
                id: id,
                text: tokenizer.decode(tokens: [id], skipSpecialTokens: false)
            )
        }
    }
}
```

`MockLLMService` exposes two stub fields:

```swift
var stubbedTokens: [String: [TokenPiece]] = [:]   // keyed by exact prompt
var tokenizeError: Error?
```

…and implements:

```swift
@MainActor
func tokenize(_ text: String) async throws -> [TokenPiece] {
    if let error = tokenizeError { throw error }
    if text.isEmpty { return [] }
    return stubbedTokens[text] ?? stubbedTokens[""] ?? []
}
```

The `""` fallback lets a test "stub once for any input" by setting `stubbedTokens[""]`.

**Test contract** (`LLMServiceProtocolTokenizeTests` or inlined in `Level2ViewModelTests`):

- `tokenize("")` returns `[]` on both real and mock.
- Mock: `stubbedTokens["我"] = [TokenPiece(id: 1, text: "我")]` causes `tokenize("我")` to return that array.
- Mock: `stubbedTokens[""] = [TokenPiece(id: 99, text: "anything")]` is the catch-all used when no exact match is set; the test for "no exact match returns catch-all" goes here.
- Mock: `tokenizeError` causes `tokenize` to throw; consumer sees it bubble up to the view model's error banner.

### 5.3 `Level2ViewModel`

```swift
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
        case direction = 1   // "想想 AI 最熟悉的词"
        case example = 2     // also autofills the example word
    }

    private let service: LLMServiceProtocol
    private let progressStore: ProgressStore
    private let hint2ExampleText: String

    // step state
    var step: Step = .hook

    // playing state
    var rawText: String = "" { didSet { onRawTextChanged() } }
    var tokens: [TokenPiece] = []
    var attemptCount: Int = 0
    var hintTier: HintTier = .none

    // persisted mirror
    private(set) var bestCharCount: Int = 0
    var isPassed: Bool { bestCharCount > 0 || progressStore.isComplete(2) }

    // error display
    var errorBanner: String?
    private var tokenizeTask: Task<Void, Never>?

    init(service: LLMServiceProtocol,
         progressStore: ProgressStore = .shared,
         hint2ExampleText: String = Level2Constants.hint2ExampleText) {
        self.service = service
        self.progressStore = progressStore
        self.hint2ExampleText = hint2ExampleText
        self.bestCharCount = progressStore.bestCharacterCount(2)
    }

    func acknowledgeHook()    { step = .demo }
    func acknowledgeDemo()    { step = .challengeIntro }
    func acknowledgeChallenge() { step = .playing }
    func acknowledgePassed()    { step = .playing }   // tap "continue grinding"

    /// Recompute tokens for the current rawText. Always called from
    /// `rawText`'s `didSet`. Cancellation-coalesced via `tokenizeTask`.
    private func onRawTextChanged() { … }

    /// Test hook: await the latest tokenize task so a test can deterministically
    /// assert on `tokens` / `step` / persisted state after a `rawText` change.
    /// Returns immediately if no task is in flight.
    func waitForPendingTokenize() async { … }

    /// Whether the current `tokens.count == 1` AND `rawText` has at least
    /// one non-whitespace grapheme. Computed eagerly when tokens update.
    private(set) var isPassing: Bool = false

    /// Recompute `isPassing`, persist best metric, advance step, escalate hint
    /// tier. Called from inside `onRawTextChanged()` after `tokens` is written.
    private func checkPassAndPersist() { … }

    /// Compute stars (0–3) from current best char count. Public for `PassedView`.
    var earnedStars: Int { … }

    /// Sets `rawText = hint2ExampleText`. Triggered by `HintBanner` tier-2.
    func applyHint2Example() { rawText = hint2ExampleText }
}
```

`rawText.didSet` calls `onRawTextChanged()` which:

1. Cancels any prior `tokenizeTask`.
2. Spawns a new one that awaits `service.tokenize(rawText)` and writes `tokens`.
3. Recomputes `isPassing`, then calls `checkPassAndPersist()`.

The `didSet` path is the single entrypoint for play-state mutation. Manually setting `rawText` (e.g. for hint 2 autofill) re-runs the same pipeline, so pass detection always reflects the current visible input. Tests change `rawText` then call `await waitForPendingTokenize()` before asserting.

`checkPassAndPersist()`:

- If `isPassing`: writes `bestCharCount` if larger (monotonic), persists via `progressStore.setBestCharacterCount(2, n)`, sets `step = .passed`, resets `attemptCount = 0`, sets `hintTier = .none`.
- Else if `tokens.count > 1`: increments `attemptCount`. Escalates `hintTier`: at 5 → `.direction`, at 10 → `.example` (and `HintBanner` will read `hintTier == .example` to render the example word + autofill once).
- Else (e.g. empty / whitespace / single whitespace token): no-op.

**Test contract** (`Level2ViewModelTests`, TDD). All `rawText` mutations require `await waitForPendingTokenize()` before asserting on `tokens` / `step` / persisted state — the tokenize call is async and runs off `rawText`'s `didSet`.

*Step transitions:*

- New instance → `step == .hook`.
- `acknowledgeHook()` → `step == .demo`.
- `acknowledgeDemo()` → `step == .challengeIntro`.
- `acknowledgeChallenge()` → `step == .playing`.
- `acknowledgePassed()` returns `step` to `.playing` (replay path).

*Pass detection:*

- `vm.rawText = "我"; await vm.waitForPendingTokenize()` (mock returns 1 piece) → `step == .passed`; `bestCharCount == 1`; `ProgressStore.setBestCharacterCount(2, 1)` invoked exactly once; `attemptCount == 0`.
- `vm.rawText = ""; await vm.waitForPendingTokenize()` (mock returns `[]`) → `step` stays in `.playing`.
- `vm.rawText = "   "; await vm.waitForPendingTokenize()` (mock returns 1 piece whose `text == " "`) → `step` does **not** flip to `.passed` (the whitespace guard).
- `vm.rawText = "我爱"; await vm.waitForPendingTokenize()` (mock returns 2 pieces) → `step` stays in `.playing`; `attemptCount == 1`.

*Persistence:*

- On pass with `rawText.count == 7`, `bestCharCount == 7` and `ProgressStore.bestCharacterCount(2) == 7`.
- A subsequent pass with `rawText.count == 5` does **not** lower `bestCharCount`; calls to `setBestCharacterCount(2, 5)` are no-ops because the store keeps the max.
- `bestCharCount` is restored from `progressStore.bestCharacterCount(2)` at `init`. Test passes by injecting a `ProgressStore` whose `bestCharacterCount(2)` returns 7 and asserting `vm.bestCharCount == 7` after `init` returns.

*Hint tier:*

- 5 failed attempts → `hintTier == .direction`.
- 10 failed attempts → `hintTier == .example`; the next render of `HintBanner` autofills `rawText` to `hint2ExampleText` exactly once. (Tests assert `vm.hintTier == .example`; the autofill side-effect is verified via a UI integration test in §12.)
- Successful pass → `attemptCount == 0`, `hintTier == .none`.
- `applyHint2Example()` sets `rawText = hint2ExampleText`; `hint2ExampleText` value can be injected via the `init` parameter (default pulls from `Level2Constants`).
- `earnedStars`: `bestCharCount >= star3Threshold` → 3; `>= star2Threshold` → 2; `>= star1Threshold` → 1; else 0. Testable independent of the View.

*Error path:*

- `service.tokenize` throws → `errorBanner` set; `tokens` retains its previous value (stale, but predictable); no step transition; `attemptCount` not incremented.

### 5.4 `Level2FlowView`

```swift
struct Level2FlowView: View {
    @Bindable var viewModel: Level2ViewModel

    var body: some View {
        Group {
            switch viewModel.step {
            case .hook:           HookView(onContinue: viewModel.acknowledgeHook)
            case .demo:           DemoView(viewModel: viewModel, onContinue: viewModel.acknowledgeDemo)
            case .challengeIntro: ChallengeIntroView(onContinue: viewModel.acknowledgeChallenge)
            case .playing:        PlayingView(viewModel: viewModel)
            case .passed:         PassedView(viewModel: viewModel,
                                             onContinueGrinding: viewModel.acknowledgePassed,
                                             onGoToLevel3: {})
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.step)
    }
}
```

The `onGoToLevel3` closure shows a brief toast / alert ("Level 3 coming soon"). Level 3 is out of scope; we do not route into a placeholder.

### 5.5 `HookView`

```
┌──────────────────────────────────────┐
│                                      │
│                                      │
│  AI 其实根本不认识字。                  │
│                                      │
│  它眼中的世界，长得很奇怪。              │
│                                      │
│                                      │
│         [ 带我看看 ]                  │
│                                      │
└──────────────────────────────────────┘
```

Pure static text + one button. No state. Bottom-pinned button for thumb reach. **No unit test**; built directly and verified manually.

### 5.6 `DemoView`

```
┌──────────────────────────────────────┐
│                                      │
│  输入几个字，看看 AI 是怎么切的            │
│                                      │
│  ┌────────────────────────┐  [↑]      │
│  │ 我爱北京                 │          │
│  └────────────────────────┘            │
│                                      │
│  [ 我爱北京 ] [ unbelievable ] [ 🌧 ]   │
│                                      │
│  ┌────────┬────┬────┬────┐            │
│  │ 我     │ 爱 │ 北京 │                │
│  └────────┴────┴────┴────┘            │
│                                      │
│  看到了吗，AI 不按字读，它把文字切成       │
│  一块块积木，这些积木叫 token。AI 只       │
│  认识 token。                          │
│                                      │
│  [ 我来试试 → ]                       │
└──────────────────────────────────────┘
```

Behaviors:

- Pre-fills `viewModel.rawText = "我爱北京"` on `.onAppear`. `rawText`'s `didSet` triggers tokenize; tokens render in the block row.
- Three inspiration chips: tap replaces `rawText` with the chip's text. Chips are `["我爱北京", "unbelievable", "\u{1F327}\u{FE0F}"]` (rain-cloud emoji), localized via a `LocalizationValue` macro.
- The "我来试试" button is enabled only after the user has typed (or tapped a chip) at least once. Once enabled, it stays enabled. (Encourages exploration without blocking forever.)

**No unit test.** Visual primitive.

### 5.7 `ChallengeIntroView`

```
┌──────────────────────────────────────┐
│                                      │
│   既然 AI 是按积木来切的，什么东西能让它     │
│   一整块就装下呢。                        │
│                                      │
│   你的任务：                            │
│   找一段尽可能长的内容，但让 AI 只用         │
│   一整块积木就装下它。                    │
│                                      │
│   屏幕上：左边是你写的字数，右边是 AI 切     │
│   成的块数。让块数保持在一块，字越多越好。   │
│                                      │
│         [ 开始挑战 → ]                  │
└──────────────────────────────────────┘
```

Single static text + one button. **No unit test.**

### 5.8 `PlayingView`

```
┌──────────────────────────────────────┐
│  你的输入                              │
│  ┌────────────────────────┐  [↑]      │
│  │ <rawText>                │          │
│  └────────────────────────┘            │
│  [ 我 ] [ 你 ] [ 我们 ]                │   ← generic inspiration chips
│                                      │
│  ┌──────────┬──────────┐             │
│  │   字     │   块      │             │   ← numerical counters
│  │    4     │    2      │             │
│  └──────────┴──────────┘             │
│                                      │
│  ┌────┬────┬────┬────┐               │
│  │ 中 │ 华 │ 人民 │ 共和 │              │   ← equal-width token blocks
│  └────┴────┴────┴────┘               │
│                                      │
│  <HintBanner>                        │   ← only present when hintTier ≥ 1
│                                      │
└──────────────────────────────────────┘
```

Behaviors:

- Input field bound to `viewModel.rawText`. Trim on commit if you'd like, but do not trim on every keystroke (the whitespace-guard inside `isPassing` covers the only case that matters).
- Generic chips (3–4): each replaces `rawText` with a common-word candidate. These are deliberately *easy* words so first-tap users feel success within their first 2 attempts and don't trigger the fallback hints.
- Numerical counters: two large numbers with subtitles above. When `tokens.count == 1 && rawText.trimmedNonEmpty`, both wrap in a small "✨ 通过" pill.
- Token blocks (`TokenBlocksView`): see §5.10.
- When `tokens.count == 1`, show a small ✨ above the blocks (visual reinforcement).

`HintBanner`:

```
┌────────────────────────────────────────────────────────┐
│ 💡 试试 AI 更熟悉的词——越日常的词越可能被它一整块装下       │   ← tier 1
└────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────┐
│ 💡 看看这个，AI 一块就装下了：                            │   ← tier 2 (with example)
│    [填示范词进输入框]                                    │
└────────────────────────────────────────────────────────┘
```

The tier 2 banner *autofills* `viewModel.rawText` to the example word when it first appears. The user can edit from there. If the user clears the autofilled word, the hint banner stays put; the autofill is one-shot per `attemptCount` crossing the 10 threshold.

### 5.9 `TokenBlocksView`

Equal-width colored blocks. When `tokens.count == 1`, switch to an "exploded" treatment for that single block: enlarged, warm-color gradient, double outline, gentle scale animation.

```swift
struct TokenBlocksView: View {
    let tokens: [TokenPiece]

    var body: some View {
        if tokens.isEmpty {
            // Placeholder: a row of N empty outlined rectangles is too noisy.
            // Show nothing; the counters above still report 0 / 0.
            EmptyView()
        } else if tokens.count == 1 {
            singleBlockExplosion(token: tokens[0])
        } else {
            HStack(spacing: 8) {
                ForEach(tokens) { t in
                    Text(t.text)
                        .font(.body.monospaced())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(blockColor(for: t))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    …
}
```

**Block coloring rule:** deterministic hash on `t.id % paletteSize`. We don't pre-define "color by frequency" because (a) we don't know frequency at the view layer, (b) it adds coupling to the tokenizer state. Stable per-id color is enough to give each block a distinct identity and makes the user's input feel preserved across re-renders.

**Single-block explosion visuals:**

- Padding 24/16 (vs. 12/8 for normal blocks).
- Background: linear gradient from one palette color to the next (warm palette: yellow → orange).
- Two-ring outline: 4pt white inset, 4pt `accentColor` outer.
- A scale-in transition (0.92 → 1.0 over 0.25s easeOut) on first appearance.

**No unit test.** Visual primitive.

### 5.10 `PassedView`

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│  🏆 通过                                                │
│                                                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │  你装下的内容：<rawText>                          │  │   ← summary
│  │  AI 用 1 块就装下了                                │  │
│  │  装下了 7 个字                                       │  │
│  └────────────────────────────────────────────────────┘  │
│                                                        │
│                  ★  ★  ★   ←  earned stars              │
│                                                        │
│  你已经发现了 AI 切积木的秘密——                         │   ← narrative
│  越熟悉的内容切得越整，越陌生的内容切得越碎。               │
│                                                        │
│  ──────────────────────────────────────────────────────  │
│                                                        │
│  Level 3 预告：                                        │   ← bridge
│  现在你知道 AI 怎么读你的字了。可是同样一句话            │
│  喂给它，它每次接的词却不一样——这背后藏着                │
│  一个旋钮。                                              │
│                                                        │
│  [ 再刷一次 ]   [ Level 3 → ]                          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

Behaviors:

- "再刷一次" → `onContinueGrinding` (back to `.playing`).
- "Level 3 →" → shows a brief toast "Level 3 coming soon" (out of scope).

Star count derivation:

- `★`  earned iff `bestCharCount >= Level2Constants.star1Threshold` (3).
- `★★` earned iff `bestCharCount >= Level2Constants.star2Threshold` (5).
- `★★★` earned iff `bestCharCount >= Level2Constants.star3Threshold` (7).

Thresholds are constants in `Level2Constants.swift`, populated from the probe script (§6) run once during development. The spec ships initial values 3 / 5 / 7; the implementation commit that lands these constants MUST be the commit that also runs the probe against the chosen word bank and confirms those values produce three achievable but distinct star tiers. If the probe contradicts the chosen values, adjust the constants in the same commit (or re-run with a different word bank). The spec's behavior contract is `>=` comparisons, not specific numeric thresholds — TDD tests for "earning 1 star at 3+ chars" use `>=` so threshold changes don't break tests.

**No unit test for the view body.** Star derivation is unit-tested via a `Level2ViewModel.starCount()` computed property (returns 0–3 from `bestCharCount`).

### 5.11 `Hint2ExampleText` and star thresholds

Hardcoded constants, defined in one place:

```swift
enum Level2Constants {
    /// Tokenizes with the real Qwen3-0.6B tokenizer. Calibrated via
    /// `scripts/probe-tokenizer.swift` (see §6). Initial values 3 / 5 / 7.
    static let star1Threshold = 3
    static let star2Threshold = 5
    static let star3Threshold = 7

    /// The autofilled hint-2 example word. Initial value: "我". Calibrated
    /// by re-running the probe with the goal of finding a single-token
    /// that the Chinese-trained Qwen3 has seen many times.
    static let hint2ExampleText = "我"
}
```

Why a single character is enough for the example: the design goal of stage 5 fallback is to demonstrate that **one Chinese character is a single token**, period. A 1-character example teaches the rule of the level faster than a longer word would. The user then naturally types longer things to chase stars.

## 6. Star threshold calibration probe

```swift
// scripts/probe-tokenizer.swift
//
// One-shot CLI. Build a minimal CLI Mac app or use `swift run` against
// a Package.swift snippet. Loads Qwen3-0.6B (one shot), then prints:
//
//     word                | tokens | chars
//     --------------------+--------+------
//     我                  | 1      | 1
//     中华人民共和国         | 1      | 7
//     unbelievable        | 3      | 12
//     ...
//
// Run once during development, eyeball the column ratios, set
// Level2Constants.starNThreshold values that produce three achievable but
// distinct tiers, then delete or .gitignore the script.
//
// Output is consumed by humans only; not part of the build.
```

The script is **not** unit-tested. It is a developer convenience used during initial threshold calibration. After calibration, the chosen thresholds live in `Level2Constants.swift` and the script may be deleted (or, if kept around for future re-calibration against a different model, marked `@available(*, deprecated, message: "…")`).

The probe needs a way to load the tokenizer without running the model. Investigation during implementation will pick the cheapest path: it may be possible to `init Qwen3Tokenizer` directly from `mlx-swift` without loading the full language model. If not, the probe loads the full model — slower, but acceptable for a one-shot developer utility.

**Tradeoff acknowledged:** alternative is to set the star thresholds empirically from Level 1 experience + Qwen3 tokenizer knowledge. That's faster but lets drift in if a future model swap changes tokenization behavior.

## 7. Data flow

### 7.1 First-time entry (level uncomplete)

```
AppRootView
  → LevelShellView
       Level2Session(viewModel: Level2ViewModel(service: LLMService()))
       .makeContentView() → Level2FlowView(viewModel: vm)
  body: switch vm.step
  → .hook → HookView → [ 带我看看 ] → vm.acknowledgeHook() → .demo
  → .demo → DemoView
       rawText preset = "我爱北京" → didSet → service.tokenize → tokens render
       user taps chip / types       → rawText changes → tokens re-render
       [ 我来试试 ]                   → vm.acknowledgeDemo() → .challengeIntro
  → .challengeIntro → ChallengeIntroView
       [ 开始挑战 ]                    → vm.acknowledgeChallenge() → .playing
  → .playing → PlayingView
       user types "我"                → rawText.didSet → tokenize → tokens.count == 1
                                       → isPassing → step = .passed
                                       → progressStore.setBestCharacterCount(2, 1)
                                       → evaluate() → Level2Session.isComplete = true
  → .passed → PassedView
       summary + ★☆☆ + bridge
       [ 再刷一次 ]                    → vm.acknowledgePassed() → .playing
       [ Level 3 → ]                  → toast "coming soon"
```

### 7.2 Fallback hint escalation

```
attemptCount == 5       → hintTier = .direction       (banner appears, light style)
attemptCount == 10      → hintTier = .example
                          (banner switches to heavy style + applies hint2ExampleText
                           once; user can edit the field)
next pass OR clear      → attemptCount = 0, hintTier = .none
```

### 7.3 Subsequent passes / star grinding

```
.passed → tap "再刷一次" → .playing → user edits rawText → tokens.count == 1 again
                                                          → step = .passed
                                                          → progressStore.setBestCharacterCount(2, N)
                                                          (only writes if N > existing best)
                                                          → bestCharCount updated → ★ count moves
```

### 7.4 Error path

```
service.tokenize throws  → vm.errorBanner = "…" for ~3s
                         (same auto-clear Task pattern as Level1ViewModel)
                         → view renders the previous tokens (stale)
                         → no step transition, no hint tier change
```

## 8. State interactions

| Trigger                                        | State change                                                                  |
|------------------------------------------------|-------------------------------------------------------------------------------|
| App launch with Level 2 uncomplete             | vm.step = .hook → .demo → .challengeIntro → .playing (user-driven)            |
| App launch with Level 2 already complete       | same as above; previous pass is preserved in ProgressStore                      |
| `service.tokenize` returns count == 1 + non-blank | step .playing → .passed; attemptCount = 0; bestCharCount persisted             |
| Tokenize returns count > 1                     | attemptCount += 1; at 5 ⇒ hintTier = .direction; at 10 ⇒ hintTier = .example + hint2ExampleText autofilled once |
| User taps "带我看看" / "我来试试" / "开始挑战" | step advances                                                                |
| User taps "再刷一次" on PassedView             | step .passed → .playing                                                       |
| User taps "Level 3 →"                          | toast shown; no state change (Level 3 is out of scope)                       |
| `tokenize` throws                              | errorBanner shown for ~3s                                                     |
| Level 1 → Level 2 transition                   | existing LevelRegistry logic picks first not-complete; unchanged              |

## 9. Localization

New keys in `Resources/Localizable.xcstrings` (en Base + zh-Hans). All player-facing strings.

| Key                                | en | zh-Hans |
|------------------------------------|----|---------|
| `level2.title`                     | `Level 2` | `第二关` |
| `level2.subtitle`                  | `It reads the world in blocks` | `它眼中的世界` |
| `level2.goal`                      | `Find content that fits in a single block` | `找到一段内容，让 AI 用一块积木就装下它` |
| `level2.hook.body`                 | `AI actually doesn't know any characters at all. The world it sees looks very strange.` | `AI 其实根本不认识字。它眼中的世界，长得很奇怪。` |
| `level2.hook.cta`                  | `Show me` | `带我看看` |
| `level2.demo.prompt`               | `Type a few characters and see how AI chops them up.` | `输入几个字，看看 AI 是怎么切的` |
| `level2.demo.reveal`               | `See? AI doesn't read character by character. It chops text into blocks — those blocks are called tokens. AI only knows tokens.` | `看到了吗，AI 不按字读。它把文字切成一块块积木，这些积木叫 token。AI 只认识 token。` |
| `level2.demo.cta`                  | `I'll try` | `我来试试` |
| `level2.challengeIntro.body`       | `If AI chops by blocks, what could make it fit everything into a single block? Find the longest content you can that still fits in one block. Below: left is your character count, right is AI's block count. Keep the block count at 1 and the character count as high as possible.` | `既然 AI 按积木切，那什么能让它一整块就装下？找一段尽可能长的内容，但让 AI 只用一块积木就装下它。下方：左是你写的字数，右是 AI 切出的块数。让块数保持在一块，字越多越好。` |
| `level2.challengeIntro.cta`        | `Start` | `开始挑战` |
| `level2.input.caption`             | `Your input` | `你的输入` |
| `level2.input.placeholder`         | `Type here…` | `在这里输入…` |
| `level2.counters.chars`           | `characters` | `字` |
| `level2.counters.blocks`          | `blocks` | `块` |
| `level2.counters.passed`          | `✨ passed` | `✨ 通过` |
| `level2.hint.tier1`               | `Try a word AI sees a lot — common words are more likely to fit in one block.` | `试试 AI 更熟悉的词——越日常的词越可能被它一整块装下。` |
| `level2.hint.tier2`               | `Look — AI packs this whole word into a single block. The field is now filled with an example; try editing it.` | `看这个——AI 把这一整个词装进了一块。输入框已经预填了示范词，试着改一改。` |
| `level2.passed.title`             | `You did it` | `你做到了` |
| `level2.passed.summary.youPacked` | `You packed` | `你装下了` |
| `level2.passed.summary.intoBlocks`| `characters into 1 block` | `个字，AI 只用 1 块` |
| `level2.passed.recap`             | `You just discovered how AI reads — no characters, only blocks. The more familiar something is, the bigger the block. The less familiar, the more fragmented.` | `你刚刚发现了——AI 眼里没有字，只有积木块。越熟悉的内容切得越整越大块，越陌生的内容切得越碎。` |
| `level2.passed.continueGrinding`  | `Try again for more stars` | `再刷一次` |
| `level2.passed.goToLevel3`        | `Level 3 →` | `Level 3 →` |
| `level2.level3Toast`              | `Level 3 coming soon` | `Level 3 即将上线` |

Spec language is plain: no `分词`, `词汇表`, `置信度`, `BPE`, `词嵌入`. The single technical word `token` is allowed and appears exactly once, on the demo screen, with the explanation "the blocks are called tokens" inside `level2.demo.reveal`.

## 10. Out of Scope (Reminder)

- Level 3 itself (sampling, temperature knob, etc.).
- `Views/Chat/` deletion (legacy, unrelated).
- `Views/Common/` new primitives (none needed).
- Animation polish beyond the existing 0.2s `easeInOut` standard.
- Localization beyond the `Localizable.xcstrings` keys listed in §9.
- Em-dash / curly-quote normalization. Grapheme counts match user perception for the input we expect.
- `PassCelebrationView`'s exact look-and-feel being reused. Passed here is a separate view because its content is different (chars, not probability).
- A typeahead / autocomplete over common words. Out of scope; would shift the level from "user discovers the rule" to "user picks from a menu".

## 11. Open Questions

- **Token text decoration.** When `tokenizer.decode(tokens: [id])` returns a leading-space-bearing string (Qwen3 uses `▁` internally; the decoder may convert to ` `), the displayed block has visible leading whitespace. The spec says we do not trim — `text` is shown literally. Confirm with the user during implementation by looking at the first chip's render.
- **`LevelHeaderView.bestSoFarKind` routing.** Currently a small refactor; either expose `LevelSession.bestSoFarKind` and switch on it in `LevelHeaderView`, or add a `headerSubtitleFor(_ session:)` method. Pick at impl time. Not a blocker.
- **Hint-2 autofill permanence.** If the user clears the autofilled word, the hint banner stays put. If they then type their own word and pass, `attemptCount` resets and the banner disappears. Reasonable behavior; documenting explicitly here because the more conservative choice (banner stays until explicit dismiss) is also defensible.
- **Star threshold probe deployment.** Whether to keep `scripts/probe-tokenizer.swift` checked in or gitignored is a tiny decision made at impl time. The probe itself is not a build dependency.
- **Localization tone for the toast.** "Level 3 coming soon" is shipped; UI text in §9 may be revisited with a Chinese-only-speaker review.

## 12. Test plan summary

| Suite                                  | Covers                                                                 |
|----------------------------------------|------------------------------------------------------------------------|
| `Level2ViewModelTests`                 | Step transitions; pass detection; hint tier escalation; persistence     |
| `ProgressStoreCharacterCountTests`     | new `bestCharacterCount` mirror methods (writes are monotonic-max)      |
| `LLMServiceProtocolTokenizeTests`      | mock contract: stubbedTokens, error path, empty input                   |
| `Level2SessionEvaluateTests`           | `evaluate()` flips `isComplete` once, writes `bestCharCount`           |
| Manual                                 | `HookView`, `DemoView`, `ChallengeIntroView`, `PlayingView`, `TokenBlocksView`, `PassedView`, `HintBanner` |

Manual tests are run on the iPhone 17 simulator per the README's `xcodebuild` instructions. No view-body unit tests.

## 13. Acceptance criteria

A reviewer can decide this slice is done when:

1. `xcodebuild test-without-building … -only-testing:llm-visualizerTests` is green on all suites in §12.
2. `xcodebuild … build` builds clean.
3. Manual playthrough (iPhone 17 simulator): hook → demo → challengeIntro → playing → 1-token pass within 3 attempts → passed → "再刷一次" → 3-token word through one prompt → progressStore stores best; `bestSoFar` on the header reads `7 chars` (or whatever the calibration ended at).
4. Typing random gibberish triggers `hintTier = .direction` after 5 attempts and `hintTier = .example` after 10 (with autofill).
5. Killing and relaunching the app lands on `.hook` again with `bestSoFar` preserved (level 2 marked complete from `ProgressStore.setComplete(2, true)`).
6. No regressions in Level 1 (existing tests still pass, manual play still passes).

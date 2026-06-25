# Onboarding Flow + Level 1 (Next-Token Confidence Challenge)

**Date:** 2026-06-23
**Status:** Draft (pending user review)
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+

## 1. Goal

Add a level-based LLM-visualization mode on top of the existing chat app.
This slice ships **one complete loop**: a 3-step onboarding that primes the
user to notice model certainty, plus **Level 1** — a challenge where the user
discovers that for highly predictable contexts the model puts near-100%
probability on one next token.

The slice also installs a minimal **Level abstraction** (protocol + registry +
progress store) so that future levels (L2–L7, defined elsewhere) can be added
one at a time by conforming to the protocol — without redesigning the app
shell.

## 2. Scope

**In scope (this slice):**

- 3-step onboarding flow (Opening → Free Play → Challenge Intro)
- Level 1 (input → next-token probability distribution → >90% goal)
- Full-screen pass celebration overlay when the user clears Level 1
- `LLMService.predictNextTokens(prompt: String, topK: Int)` — one forward
  pass + softmax + top-K (no generation)
- `LevelSession` base class + `LevelRegistry` (currently registers only
  Level 1)
- `ProgressStore` — UserDefaults-backed set of completed level IDs
- `OnboardingFlow` — state machine for the 3 onboarding steps, gated by
  `hasSeenOnboarding`
- `LevelShellView` — header (title / subtitle / goal / best record) +
  level content + pass overlay
- Six reusable UI primitives (`ProbabilityBarsView`,
  `InspirationButtonsView`, `NarratorLineView`, `ChallengeIntroCard`,
  `PassCelebrationView`, `LevelHeaderView`) — built for L1 but written so
  later levels can drop them in
- Localization: extend the existing `Localizable.xcstrings` catalog with
  the new L1 strings (English + zh-Hans)
- Unit tests: `predictNextTokens`, Level 1 pass evaluation, Onboarding
  state machine, ProgressStore

**Out of scope (this slice, deferred to future slices):**

- Levels 2–7 (specific implementations). The protocol is shaped to accept
  them, but no stubs, no placeholder pages, no skeleton views.
- `LLMService` extensions beyond `predictNextTokens` — specifically:
  - `tokenize(text:)` (needed by Level 2)
  - `attentionWeights(prompt:, layer:, head:)` (needed by Level 5)
  - `loadModel(name:)` (needed by Level 7)
  - `generate(prompt:, temperature:)` parameterization (needed by Level 3)
  - "judge model wrong" mechanism (needed by Level 6)
- A level-launcher / map UI for picking among unlocked levels. After L1
  is complete the app simply shows a "next level coming soon" message
  inline in the header. When L2 is added, the launcher will be designed.
- Modifications to `ChatView`, `ChatViewModel`, `ConversationView`,
  `MessageView`, `PromptField`, `StatusBar`, `ThinkingBlock`. They stay
  untouched (the existing chat still works as before, just no longer
  the entry point).
- Tests for visual layouts (UI tests). Manual verification only for L1.
- New languages beyond en + zh-Hans.

## 3. Architecture

```
┌───────────────────────────────────────────────────────────┐
│  llm_visualizerApp.swift                                  │
│     ├─ if !ProgressStore.shared.hasSeenOnboarding         │
│     │     OnboardingFlowView                              │
│     │       (Opening → FreePlay → ChallengeIntro → done)  │
│     └─ else                                                │
│           LevelShellView                                  │
│             ├─ LevelHeaderView                            │
│             ├─ currentLevel.makeContentView()            │
│             └─ if isComplete: PassCelebrationView overlay │
└───────────────────────────────────────────────────────────┘
                          │ uses
                          ▼
┌───────────────────────────────────────────────────────────┐
│  LevelSession (base class)                                │
│    Level1Session                                          │
│      ├─ viewModel: Level1ViewModel (@Observable)          │
│      ├─ makeContentView() → Level1View                    │
│      └─ evaluate() → top1.probability > 0.90              │
│                                                           │
│  LevelRegistry.all: [LevelSession.Type] = [Level1.self]   │
└───────────────────────────────────────────────────────────┘
                          │ uses
                          ▼
┌───────────────────────────────────────────────────────────┐
│  LLMService                                               │
│    ├─ loadModel()                  (existing)             │
│    ├─ generate(messages:…)         (existing, unchanged) │
│    └─ predictNextTokens(prompt:,   (NEW this slice)       │
│                         topK:)                            │
└───────────────────────────────────────────────────────────┘
```

Two view-model trees, both `@MainActor @Observable`:

1. **`OnboardingViewModel`** — owns `phase: OnboardingPhase`. Transitions
   `opening → freePlay → challengeIntro → done`. Knows nothing about
   Level 1's internals; just hands control to `LevelShellView` when done.

2. **`Level1ViewModel`** — owns `prompt`, `topCandidates: [TokenCandidate]`,
   `bestSoFar: Double`, `submitCount: Int`, `isPassed: Bool`. Drives
   `Level1View`. Knows nothing about onboarding or future levels.

## 4. Files

### 4.1 To create

```
llm-visualizer/
├── Models/
│   ├── Levels.swift                  # LevelSession base + LevelRegistry
│   ├── LevelProgress.swift           # ProgressStore (UserDefaults)
│   ├── OnboardingState.swift         # OnboardingPhase enum + transitions
│   └── TokenCandidate.swift          # (tokenId, text, probability)
├── Services/                         # (LLMService modified, see 4.3)
│   └── (no new files; new types live inside LLMService.swift or Models/)
├── ViewModels/
│   ├── OnboardingViewModel.swift
│   └── Level1ViewModel.swift
└── Views/
    ├── Onboarding/
    │   ├── OnboardingFlowView.swift     # routes by phase
    │   ├── OpeningView.swift            # pre-canned example + "这是真的吗" button
    │   ├── FreePlayView.swift           # input + bars + inspiration buttons + narrator
    │   └── ChallengeIntroView.swift     # "你可能发现了…" modal
    ├── LevelShell/
    │   ├── LevelShellView.swift         # header + content + pass overlay
    │   └── PassCelebrationView.swift    # full-screen pass animation
    ├── Level1/
    │   ├── Level1View.swift             # input + bars + submit + best-record chip
    │   ├── ProbabilityBarsView.swift    # Top-1 big card + Top-3 gray bars
    │   └── NarratorLineView.swift       # italic one-liner below bars
    └── Common/
        ├── InspirationButtonsView.swift # horizontal scrollable chips
        ├── ChallengeIntroCard.swift     # title + body + CTA
        └── LevelHeaderView.swift        # 关卡名 + 目标 + 最高纪录
```

### 4.2 To delete

None.

### 4.3 To modify

- `llm-visualizer/llm_visualizerApp.swift` — replace `ChatView` with
  `AppRootView` (a small router view that toggles between
  `OnboardingFlowView` and `LevelShellView` based on `ProgressStore` +
  local `@State`). The old `ChatViewModel(service:)` instantiation
  line is removed. `ChatView` itself and its dependencies remain
  on disk but unreferenced — easy to restore in a future slice if we
  want a "free chat" mode.
- `llm-visualizer/Services/LLMService.swift` — add
  `predictNextTokens(prompt:topK:)` to the protocol and both
  implementations (`LLMService`, `MockLLMService`).
- `llm-visualizer/Resources/Localizable.xcstrings` — add L1 strings
  (both en + zh-Hans). See §9.

## 5. Components

### 5.1 `LLMService.predictNextTokens`

New protocol method:

```swift
struct TokenCandidate: Sendable, Equatable, Identifiable {
    let id: Int              // tokenizer token id
    let text: String         // decoded token text (may include leading space)
    let probability: Double  // softmax probability, 0.0...1.0
}

protocol LLMServiceProtocol: Sendable {
    // ... existing loadModel() and generate() ...
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate]
}
```

**Real implementation** (`LLMService`):

1. Load (or reuse cached) `ModelContainer`.
2. Inside `model.perform { context in … }`:
   - Wrap `prompt` in a one-element chat message list (`role: .user,
     content: prompt`), build `UserInput(chat:)`, call
     `context.processor.prepare(input:)`.
   - Run a single forward pass via the underlying language model to get
     logits at the **last** position.
   - Apply softmax (over the vocab dimension) to get probabilities.
   - Use MLX's top-k on the probability array → `[TokenCandidate]`.
   - Detokenize each kept token id to get its text.
3. Return sorted descending by probability.

This is **not** affected by sampling parameters — it returns the model's
raw confidence distribution. (Future Level 3 may need temperature
parameterization; out of scope here.)

**Mock implementation** (`MockLLMService`): returns a deterministic stub
list driven by `stubbedPredictTopK: [TokenCandidate]?` (defaults to a
small fixture) so unit tests can pin results.

### 5.2 Level abstraction (`Levels.swift`)

```swift
import SwiftUI

@MainActor
@Observable
class LevelSession {
    let id: Int
    let title: String              // localized, e.g. "第 1 关"
    let subtitle: String           // localized, e.g. "让 AI 闭眼都猜对"
    let goalDescription: String    // localized, shown in header

    var isComplete: Bool = false {
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

    /// Subclasses override to check if the goal has been met.
    /// Should mutate `isComplete` when the goal is first met.
    func evaluate() {
        fatalError("Subclass must override evaluate()")
    }
}

enum LevelRegistry {
    /// Ordered list of level classes. The app picks the first
    /// not-yet-complete one as the "current" level.
    /// Future slices append new entries here.
    static let all: [LevelSession.Type] = [
        Level1Session.self
    ]
}
```

`Level1Session` (concrete subclass) holds a `Level1ViewModel` and exposes
its view via `makeContentView()`. Pass tracking works like this:

- `Level1View.submit()` calls `Level1ViewModel.submit()`.
- `Level1ViewModel.submit()` sets `state = .passed` when `top1Probability
  > 0.90` for the first time.
- `Level1View` observes `viewModel.state` via `.onChange(of:)`; on the
  transition `playing → passed` it calls `session.evaluate()`.
- `Level1Session.evaluate()` (override) checks the view-model's state
  and sets `self.isComplete = true` exactly once. Because
  `isComplete.didSet` writes to `ProgressStore`, the session flag and
  persistence stay in lock-step.

The base `LevelSession.evaluate()` does nothing (default = no goal
tracking) so simple levels that don't need a session-owned goal can
opt out by not overriding it.

### 5.3 `ProgressStore`

```swift
final class ProgressStore: @unchecked Sendable {
    static let shared = ProgressStore()

    private let defaults: UserDefaults
    private let seenOnboardingKey = "llmviz.hasSeenOnboarding"
    private let completedKey = "llmviz.completedLevels"

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: seenOnboardingKey) }
        set { defaults.set(newValue, forKey: seenOnboardingKey) }
    }

    func isComplete(_ levelId: Int) -> Bool {
        let set = defaults.array(forKey: completedKey) as? [Int] ?? []
        return set.contains(levelId)
    }

    func setComplete(_ levelId: Int, _ value: Bool) {
        var set = defaults.array(forKey: completedKey) as? [Int] ?? []
        if value { set.append(levelId) } else { set.removeAll { $0 == levelId } }
        defaults.set(Array(Set(set)).sorted(), forKey: completedKey)
    }
}
```

No migration / schema versioning — this is a brand-new slice, no
backwards compatibility concerns.

### 5.4 `OnboardingState` & `OnboardingViewModel`

```swift
enum OnboardingPhase: Equatable {
    case opening                       // 1st screen: pre-canned example
    case freePlay(playsSoFar: Int)     // input + bars + narrator (≥2 plays)
    case challengeIntro                // modal: "你可能发现了…"
}

@MainActor @Observable
final class OnboardingViewModel {
    enum ChallengeTrigger {
        case autoAfterDelay             // after 2nd play + 3s, auto-show
        case manualButton               // user tapped the explicit "准备好了" chip
    }

    var phase: OnboardingPhase = .opening
    private(set) var bestSoFar: Double = 0.0     // tracks top-1 across free-play

    private let service: LLMServiceProtocol
    private var modelContainer: ModelContainer?
    private var autoShowTask: Task<Void, Never>?

    init(service: LLMServiceProtocol) { self.service = service }

    func bootstrap() async { /* mirror ChatViewModel.bootstrap */ }

    /// Called by the view after each user submit during `.freePlay`.
    /// Updates `bestSoFar`, bumps the plays count, schedules the auto
    /// challenge-intro if this was the 2nd play.
    func recordPlay(top1Probability: Double) {
        bestSoFar = max(bestSoFar, top1Probability)
        let next = (currentPlays + 1)
        phase = .freePlay(playsSoFar: next)
        if next == 2 {
            autoShowTask?.cancel()
            autoShowTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard let self else { return }
                if case .freePlay(let n) = self.phase, n >= 2 {
                    self.phase = .challengeIntro
                }
            }
        }
    }

    /// Called when the user explicitly taps the "我准备好了" chip
    /// that becomes visible after the 2nd play. Cancels the auto-task
    /// and shows the challenge intro immediately.
    func showChallengeManually() {
        autoShowTask?.cancel()
        phase = .challengeIntro
    }

    /// Called when the user accepts the challenge intro.
    /// Writes persistence and invokes the closure passed by App root,
    /// which swaps `OnboardingFlowView` for `LevelShellView`.
    func acceptChallenge(onComplete: @escaping () -> Void) {
        autoShowTask?.cancel()
        ProgressStore.shared.hasSeenOnboarding = true
        onComplete()
    }

    private var currentPlays: Int {
        if case .freePlay(let n) = phase { return n }
        return 0
    }
}
```

The auto-show-vs-manual duality (auto after 3s, or manual chip) lets
impatient users skip the delay without trapping patient ones — the
manual chip becomes visible at the same moment the auto timer starts.

### 5.5 `Level1ViewModel`

```swift
@MainActor @Observable
final class Level1ViewModel {
    enum State: Equatable { case playing, passed }

    private let service: LLMServiceProtocol
    private var modelContainer: ModelContainer?

    var prompt: String = ""
    var topCandidates: [TokenCandidate] = []
    var bestSoFar: Double = 0.0     // highest top-1 seen this session
    var submitCount: Int = 0
    var state: State = .playing
    var isLoading: Bool = false
    var errorBanner: String?

    init(service: LLMServiceProtocol) { self.service = service }

    func bootstrap() async { /* mirror ChatViewModel.bootstrap */ }

    func submit() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let container = try await ensureModel()
            let candidates = try await service.predictNextTokens(
                prompt: trimmed, topK: 4)
            topCandidates = candidates
            submitCount += 1
            if let top1 = candidates.first {
                bestSoFar = max(bestSoFar, top1.probability)
                if top1.probability > 0.90, state != .passed {
                    state = .passed
                }
            }
        } catch {
            errorBanner = error.localizedDescription
            // auto-clear after 3s
        }
    }

    func continueAfterPass() {
        // user dismissed the celebration overlay; allow more submissions
        // but `state` stays `.passed` so the goal indicator can show ✓
        state = .passed
    }

    private func ensureModel() async throws -> ModelContainer {
        if let m = modelContainer { return m }
        let m = try await service.loadModel()
        modelContainer = m
        return m
    }
}
```

**Pass evaluation contract:** `evaluate()` on `Level1Session` simply calls
`viewModel.submit()` is the path; the session flips `isComplete` when
the view-model's `state` first transitions to `.passed`.

### 5.6 Views

#### `Level1View`

```
┌─────────────────────────────────┐
│  [你的输入]                     │ ← section header
│  今天天气真[|]                  │ ← large editable prompt display
│  [我爱吃] [明天我要去] [人生…]  │ ← InspirationButtonsView
├─────────────────────────────────┤
│                                 │
│  ╔═══════════════════════════╗  │
│  ║ AI 最可能的下一词         ║  │ ← ProbabilityBarsView top-1 card
│  ║        好                 ║  │
│  ║       32%                 ║  │
│  ╚═══════════════════════════╝  │
│                                 │
│  其他可能                       │
│  ── 不 ──── 18%                 │ ← ProbabilityBarsView gray rows
│  ── 的 ──── 14%                 │
│  ── 很 ────  9%                 │
│                                 │
│  这次 AI 有点犹豫…              │ ← NarratorLineView (if visible)
│                                 │
├─────────────────────────────────┤
│  最高纪录 32%    [   提交   ]   │ ← best-record chip + submit
└─────────────────────────────────┘
```

- During onboarding phase 2 (`freePlay`), the "最高纪录" line and submit
  button are present but there's no goal indicator — the narrator is the
  only "extra" element.
- During phase 3 / Level 1, the header shows "目标：让 Top-1 超过 90%"
  and the best-record chip shows percentage progress toward that goal.

#### `ProbabilityBarsView`

Two-section layout (per the brainstorming decision "Top-1 大卡 + Top-3 灰条"):

- **Top-1 card**: full-width, white background, 12pt rounded corners,
  subtle shadow. Centered text: small label "AI 最可能的下一词",
  large token (≈48pt bold), large percentage (≈22pt, accent color).
- **Other candidates**: small label "其他可能", then 3 gray rows. Each
  row: 36pt token label · thin (10pt) progress bar · 12pt right-aligned
  percentage.
- Colors: pass state recolors the Top-1 card border + percentage to
  green (`#22c55e`); bars stay the same shade.

#### `InspirationButtonsView`

A horizontal scroll of chips. Each chip = short sentence fragment.
Sentences are mixed certainty levels so the user naturally observes the
range. Initial fixture (subject to fine-tuning during implementation):

| Fragment           | Expected top-1 prob | Notes                          |
|--------------------|---------------------|--------------------------------|
| `我爱吃`           | ~10–15%             | many food words compete        |
| `明天我要去`       | ~10–20%             | many destinations compete      |
| `人生最重要的是`   | ~25–35%             | 健康/快乐/家庭 common          |
| `今天天气真`       | ~30–50%             | 好 dominant but not extreme    |
| `太阳从东边`       | ~75–90%             | 升起 is very predictable       |
| `2 + 2 =`          | ~95–99%             | unlocks the goal               |
| `中国的首都是`     | ~95–99%             | 北京                          |

Tapping a chip fills `prompt` (does NOT auto-submit — user still presses
the submit button).

#### `NarratorLineView`

Italic one-line caption, 13pt, secondary color, centered. Rendered
between the bars and the submit area. Visibility controlled by parent.

Dynamic text rules (used during onboarding `freePlay`):

- `top1Probability ≥ 0.70` → "这次 AI 挺确定的。"
- `0.40 ≤ top1Probability < 0.70` → "这次 AI 有点拿不准。"
- `top1Probability < 0.40` → "这次 AI 很犹豫，几个词分数差不多。"

After onboarding (in Level 1 mode), the narrator is hidden so it doesn't
distract from the goal.

#### `ChallengeIntroCard`

Modal card shown over `FreePlayView` at the start of phase 3. Contains:

- Title: "你可能发现了…"
- Body: "有时候 AI 很确定，有时候很犹豫。\n那么问题来了——\n**你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？**"
- Goal chip: "目标：让 AI 对下一个词的预测超过 90%"
- Anchor chip: "你刚才最高才 68%，挑战一下" (uses the actual best-so-far)
- Primary action button: "我准备好了" → calls `acceptChallenge()`

#### `PassCelebrationView`

Full-screen overlay (per brainstorming decision "全屏覆盖庆祝"):

- Radial gradient background (light blue → white).
- Centered stack: 🏆 emoji · "FIRST CLEAR" small caps · 32pt bold title
  ("你让 AI 闭眼都猜对了") · 15pt body sentence (a single line,
  localized) · primary button "再来一次" · footer hint "下一关在路上"
- Tapping "再来一次" dismisses the overlay; `Level1ViewModel.state`
  stays `.passed`. User can keep submitting and exploring.

#### `LevelHeaderView`

Sticky top header above the level content:

```
第 1 关 · 让 AI 闭眼都猜对
目标：让 Top-1 概率超过 90%   ·   最高纪录：68%
```

Two-line layout: title on top, goal + best-record on bottom. After
`isComplete = true`, append a small ✓ badge to the title row.

## 6. Data Flow

### 6.1 App launch

```
App.init
  ↓
AppRootView(@State showOnboarding: Bool)
  ↓
ProgressStore.shared.hasSeenOnboarding?
  ├─ false → showOnboarding = true
  └─ true  → showOnboarding = false

AppRootView body:
  if showOnboarding:
    OnboardingFlowView(onComplete: { showOnboarding = false })
  else:
    LevelShellView(...)
```

The flag is local `@State` to the root view; `OnboardingFlowView` is
given an `onComplete` closure that flips it. We deliberately do NOT
re-read `ProgressStore.hasSeenOnboarding` in the root body each render
— that would cause an unnecessary re-render after persistence write. The
closure path is the only way `showOnboarding` flips false.

### 6.2 Onboarding flow

```
OnboardingFlowView (phase: .opening)
  ├─ model bootstrap (load Qwen3-0.6B)
  ├─ render OpeningView with pre-canned "今天天气真" → call
  │   predictNextTokens once, show bars
  └─ "这是真的吗？我来试试" button → phase = .freePlay(0)

OnboardingFlowView (phase: .freePlay(0))
  ├─ render FreePlayView (Level1View shell + inspiration buttons +
  │   empty input + narrator hidden)
  ├─ on user submit:
  │     viewModel.submit() → bars update
  │     recordPlay(top1Probability: viewModel.topCandidates.first?.probability ?? 0)
  │     if playsSoFar >= 2 → narrator visible (dynamic text)
  │     if playsSoFar == 2:
  │         start a 3-second Task that will set phase = .challengeIntro
  │         ALSO show a "我准备好了" chip immediately (cancels the task
  │         and jumps to challengeIntro if tapped)
  └─ if user taps the manual chip → showChallengeManually()

OnboardingFlowView (phase: .challengeIntro)
  ├─ render ChallengeIntroView as a sheet / overlay
  ├─ on "我准备好了":
  │     acceptChallenge(onComplete: swapToLevelShell)
  └─ (no "back" button — once shown, the only way out is accept)

OnboardingFlowView dismisses → LevelShellView mounts
```

### 6.3 Level 1 play

```
LevelShellView
  └─ Level1Session.makeContentView() → Level1View(viewModel, session)
       ├─ user types prompt
       ├─ taps submit
       │     Level1ViewModel.submit()
       │       → service.predictNextTokens(prompt, topK: 4)
       │       → topCandidates = result
       │       → bestSoFar = max(...)
       │       → if top1Probability > 0.90 (first time):
       │             state = .passed
       ├─ .onChange(of: viewModel.state):
       │     if newValue == .passed:
       │       session.evaluate()  → isComplete = true
       │       show PassCelebrationView overlay
       └─ user taps "再来一次" → dismiss overlay, viewModel.continueAfterPass()
            (state stays .passed; celebration does NOT re-show on resubmit)
```

### 6.4 `predictNextTokens` call sequence

```
predictNextTokens(prompt: "今天天气真", topK: 4)
  ↓
ModelContainer.perform { context in
    let input = try await context.processor.prepare(
        input: UserInput(chat: [Chat.Message(.user, prompt)]))
    let logits = model(input.text)               // forward pass
    let lastLogits = logits[0, -1, ..]           // last position
    let probs = softmax(lastLogits)
    let (topKValues, topKIndices) = topk(probs, 4)
    let texts = topKIndices.map { tokenizer.decode([$0]) }
    return [TokenCandidate(id, text, prob), ...]
}
```

## 7. UI Design

The visual decisions captured during brainstorming (see
`.superpowers/brainstorm/18686-1782225140/content/`):

- **Probability display:** "Top-1 big card + Top-3 gray bars" — the
  visual centerpiece that frames the entire level.
- **Layout (Level 1 screen):** Prompt fixed at top (so users always see
  what they typed), bars in the middle, narrator + submit at the bottom.
- **Pass state:** Full-screen celebration overlay (not inline) — gives
  Level 1 a clear "you did it" moment.
- **Onboarding phases:** All three use the same input+bars UI; phase 2
  adds the narrator after ≥2 plays; phase 3 overlays the challenge
  intro card on top of the free-play UI.

## 8. State Interactions

| Trigger                              | State change                                              |
|--------------------------------------|-----------------------------------------------------------|
| App first launch                     | `hasSeenOnboarding` = false → OnboardingFlowView shows    |
| User clears Level 1                  | `ProgressStore.isComplete(1)` = true; `isComplete` = true on Level1Session |
| User submits with `top1Prob > 0.90`  | `Level1ViewModel.state` = `.passed`; overlay shown        |
| User taps "再来一次"                 | overlay dismissed, `state` stays `.passed`, can resubmit  |
| User restarts app after passing L1   | `LevelShellView` shows immediately, ✓ badge in header    |
| `topCandidates` empty (model error) | `errorBanner` shown for 3s, bars hidden                   |
| Submit while `isLoading`             | ignored (button disabled)                                 |

## 9. Localization

Add the following keys to `Localizable.xcstrings`. Existing en + zh-Hans
locales only. Same pattern as the localization spec (Xcode String
Catalog, source = en).

| English                                          | 中文                                    | Used in                                  |
|--------------------------------------------------|-----------------------------------------|------------------------------------------|
| `第 1 关`                                        | `第 1 关`                              | LevelHeaderView                          |
| `让 AI 闭眼都猜对`                               | `让 AI 闭眼都猜对`                     | LevelHeaderView                          |
| `目标：让 Top-1 概率超过 %@%%`                  | `目标：让 Top-1 概率超过 %@%%`         | LevelHeaderView                          |
| `最高纪录：%@%%`                                 | `最高纪录：%@%%`                       | LevelHeaderView                          |
| `你的输入`                                       | `你的输入`                              | Level1View                               |
| `AI 最可能的下一词`                              | `AI 最可能的下一词`                     | ProbabilityBarsView                      |
| `其他可能`                                       | `其他可能`                              | ProbabilityBarsView                      |
| `这次 AI 挺确定的。`                             | `这次 AI 挺确定的。`                    | NarratorLineView (high)                  |
| `这次 AI 有点拿不准。`                           | `这次 AI 有点拿不准。`                  | NarratorLineView (medium)                |
| `这次 AI 很犹豫，几个词分数差不多。`            | `这次 AI 很犹豫，几个词分数差不多。`   | NarratorLineView (low)                   |
| `这次 AI 几乎闭眼都猜对了！`                     | `这次 AI 几乎闭眼都猜对了！`           | NarratorLineView (during pass state)     |
| `换一句话试试，看 AI 怎么猜`                     | `换一句话试试，看 AI 怎么猜`           | FreePlayView                             |
| `这是真的吗？我来试试`                           | `这是真的吗？我来试试`                 | OpeningView                              |
| `它没在想，只是给每个词打分。`                   | `它没在想，只是给每个词打分。`         | OpeningView                              |
| `你可能发现了…`                                  | `你可能发现了…`                        | ChallengeIntroCard                       |
| `有时候 AI 很确定，有时候很犹豫。`               | `有时候 AI 很确定，有时候很犹豫。`    | ChallengeIntroCard body                  |
| `你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？` | `你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？` | ChallengeIntroCard body |
| `我准备好了`                                     | `我准备好了`                            | ChallengeIntroCard action               |
| `FIRST CLEAR`                                    | `FIRST CLEAR`                          | PassCelebrationView (kept English)       |
| `你让 AI 闭眼都猜对了`                           | `你让 AI 闭眼都猜对了`                  | PassCelebrationView title                |
| `当上下文足够明确，模型其实早就知道下一个词是什么。` | `当上下文足够明确，模型其实早就知道下一个词是什么。` | PassCelebrationView body |
| `再来一次`                                       | `再来一次`                              | PassCelebrationView action               |
| `下一关在路上`                                   | `下一关在路上`                          | PassCelebrationView footer               |

Localized via `Text(LocalizedStringKey(…))` for static literals and
`String(localized:defaultValue:)` for the two formatted strings (`%@%%`).

## 10. Error Handling

| Source                | Trigger                          | UI                              | Recovery                          |
|-----------------------|----------------------------------|---------------------------------|-----------------------------------|
| Model dir missing     | bundle path invalid              | red banner: "Model not found"   | manual restart                    |
| `loadModel` failure   | corrupt safetensors              | red banner: error msg (3s auto-clear) | retry submit                   |
| `predictNextTokens` failure | forward pass throws         | red banner: error msg           | retry submit                      |
| Empty prompt          | user submits blank               | submit button disabled          | —                                 |
| Submit while loading  | double-tap                       | submit button disabled          | —                                 |

Error handling mirrors the existing `ChatViewModel` pattern (transient
banner, 3-second auto-clear).

## 11. Testing

### Unit (`llm-visualizerTests/`)

- `LLMServicePredictTests`
  - Mock returns a pinned `TokenCandidate` list → `predictNextTokens`
    on the protocol mock surfaces them unchanged.
  - Empty prompt returns `[]` (mock returns empty).
  - `topK: 0` or `topK > vocab` is clamped (mock returns whatever it has;
    real impl asserts via `precondition`).
- `Level1ViewModelTests` (mocked `LLMServiceProtocol`)
  - Submit with non-empty prompt updates `topCandidates` and `bestSoFar`.
  - `submitCount` increments on each submit.
  - `top1Probability > 0.90` transitions `state` to `.passed`.
  - Subsequent submits with `top1Probability < 0.90` leave `state`
    unchanged (`.passed` is sticky).
  - Empty prompt is a no-op.
  - Best-so-far is the running max, not the most recent.
- `OnboardingViewModelTests`
  - `phase` transitions: `opening → freePlay(0) → freePlay(1) →
    freePlay(2) → challengeIntro`.
  - `acceptChallenge()` sets `ProgressStore.hasSeenOnboarding = true`.
  - `recordPlay()` does NOT auto-advance to `challengeIntro` — it only
    bumps the count (challenge intro is shown by the view based on its
    own logic).
- `ProgressStoreTests`
  - `isComplete` / `setComplete` round-trip on a fresh `UserDefaults`
    suite.
  - `hasSeenOnboarding` round-trip.
  - Setting then unsetting restores the original state.

### UI (`llm-visualizerUITests/`)

Manual verification only for this slice (no automated UI tests added).
Covered manually:

- First launch → onboarding (3 steps) → Level 1 → submit a low-confidence
  prompt → no pass → submit `2 + 2 =` → pass celebration shown.
- Dismiss celebration → continue submitting → celebration does NOT
  re-show.
- Force-quit and relaunch → straight to Level 1 with ✓ badge.
- Device language = zh-Hans → all new strings render in Chinese.

### Manual

- Real-device/simulator: full onboarding loop, level 1 pass, restart,
  localization.
- Confirm `predictNextTokens` returns **deterministic** results for a
  given prompt (no sampling randomness).
- Confirm pass-celebration overlay doesn't trap the user (always
  dismissible via "再来一次").

### TDD order

1. `TokenCandidate` struct
2. `ProgressStore` + tests
3. `Levels.swift` (`LevelSession` base + `LevelRegistry` + tests)
4. `OnboardingState` + `OnboardingViewModel` + tests
5. `LLMService.predictNextTokens` (mock impl + tests first, then real)
6. `Level1ViewModel` + tests
7. SwiftUI views (manual visual check against the brainstorming mockups
   in `.superpowers/brainstorm/…/content/`)

## 12. Risks & Mitigations

| Risk                                                   | Mitigation                                                |
|--------------------------------------------------------|-----------------------------------------------------------|
| `predictNextTokens` uses private MLX APIs that change across mlx-swift versions | Pin mlx-swift-lm version in `Package.resolved`. Wrap the new method behind `LLMServiceProtocol` so a future version change only touches the real impl, not the views. |
| Pass threshold `0.90` is too easy/hard for Qwen3-0.6B | Spec lists the inspiration fragments and their expected probabilities; tune during implementation if any are miscalibrated. |
| Onboarding-to-Level transition feels abrupt             | The ChallengeIntroCard uses the user's actual best-so-far as anchor; the spec is explicit that it must read that value dynamically, not hard-code "68%". |
| Top-3 gray bars lose readability on small phones       | Bars are minimum-width-friendly: token label fixed at 36pt, percentage fixed at 40pt, bar gets the rest. No truncation of the percentage. |
| `ChatView` removed from the app entry breaks existing flows | `ChatView` and friends stay on disk, unmodified. Only `llm_visualizerApp.swift` switches the entry. Easy to revert. |
| Inspiration chips don't actually hit 90%+ on Qwen3-0.6B | Pick fragments with very predictable continuations (math, capitals, fixed phrases). If still too soft, can add `2 + 2 =`, `9 * 9 =`, etc. without code change. |
| Mock `predictNextTokens` in tests diverges from real    | Keep `MockLLMService` and `LLMService` symmetric on the same protocol; both must return `[TokenCandidate]` with same shape. |

## 13. Out of Scope (this slice)

- Levels 2–7 (specific implementations, but the protocol is shaped to
  accept them).
- `LLMService.tokenize`, `attentionWeights`, `loadModel`, temperature
  parameterization, "judge model wrong" — all deferred to the slices
  that need them.
- Level-launcher / map screen — single-level UI only.
- Modifications to `ChatView` and friends.
- New languages beyond en + zh-Hans.
- Automated UI tests for Level 1 visuals.
- Animation polish beyond SwiftUI defaults (no custom `Animation`
  curves; the celebration overlay uses standard transitions).
- A11y audit beyond system defaults. Dynamic Type and VoiceOver work
  via standard SwiftUI components without extra config; not formally
  verified in this slice.
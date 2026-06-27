# Onboarding Redesign — Passive Examples + Dedicated Loading Screen

**Date:** 2026-06-26
**Status:** Draft (pending user review)
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+
**Replaces:** §6.2 ("Onboarding flow") of `2026-06-23-onboarding-level1-design.md` and the corresponding implementation slice (commits `bade184`..`90cf046`).

## 1. Goal

The current onboarding's Free Play phase is a near-duplicate of Level 1's
input UI — same TextField, same send button, same inspiration chips, same
probability bars, same narrator — minus the pass-evaluation wiring. The
duplication is real: the two views share ~80% of their body and will
diverge in maintenance.

This slice restructures Onboarding along two axes:

1. **Remove duplication.** Onboarding no longer mirrors Level 1's play
   surface. Free Play is deleted; what replaces it is structurally
   different (passive observation, not active input).
2. **Hide model-loading time behind a dedicated screen.** Today, model
   loading happens inside `OnboardingFlowView.task` while the user sees
   the first onboarding card transition through a brief "loading"
   state. We add a full-screen `ModelLoadingView` that owns the entire
   model bootstrap + onboarding-example pre-fetch, so the user never
   waits inside an onboarding card.

The pedagogical premise of Onboarding shifts from "tease the user with
a free copy of Level 1, then challenge them" to "show the user one
real, pre-canned model prediction with a teaching caption, then hand
off to Level 1." This treats Onboarding as a **brief classroom**,
not a **tutorial** that previews the game.

## 2. Scope

**In scope (this slice):**

- New `ModelLoadingView` — full-screen page with logo + "Loading
  model…" text + spinner, or error message + [Try again] button.
- New `AppShellViewModel` — owns model load + onboarding-example
  pre-fetch as a single state machine (`loading` / `failed(msg)` /
  `ready(hasSeenOnboarding)`). One entry point. One retry.
- New `ExampleCardView` — passive card showing a fixed prompt, a
  100-dot probability grid, and a teaching caption. No input.
- New `DotGridView` — 10×10 grid of small circles, colored by
  top-K candidate proportion. Private subview of `ExampleCardView`.
- Simplified `OnboardingViewModel` — pure state machine over a
  2-step enum (`example` / `challengeIntro`). Holds one pre-fetched
  `[OnboardingExample]`, no `service`, no `modelState`, no `bootstrap()`,
  no progress tracking.
- Pre-fetch of **one** onboarding example during model loading
  (no per-example loading screen).
- Centralize model loading in `AppRootView`. Remove bootstrap calls
  from `OnboardingFlowView` and `LevelShellView`/`Level1Session`.
- Delete `FreePlayView`, `OpeningView`, and the old `OnboardingState`
  enum (which carried `playsSoFar` and progress fields).
- Extend `Localizable.xcstrings` with "Loading model…", the
  onboarding prompt (used by both the model and the example card), and
  the example caption (English + zh-Hans).
- Unit tests (TDD-first per project convention): `AppShellViewModel`,
  `OnboardingViewModel`.

**Out of scope (this slice, deferred to future slices):**

- "Confidence ≠ correct" example (the third "confidently wrong" card
  considered during brainstorming is not in this slice). That concept
  will land in a future level.
- Replacing or augmenting `ProbabilityBarsView` (Level 1's bar chart).
  The new `DotGridView` is a separate, Onboarding-only component.
- Resurrecting or deleting `Views/Chat/` (the legacy chat, currently
  unreferenced from `AppRootView`).
- Levels 2–7. The `LevelRegistry` and `LevelSession` abstractions
  are unchanged.
- Any "On device" / "Running locally" indicator on the example cards.
  The teaching is done by captions only.
- Friendly / wrapped error messages. The loading view shows
  `error.localizedDescription` directly.
- TDD: tests cover data-layer state machines and the AppShell
  pre-fetch; SwiftUI view bodies (`ModelLoadingView`,
  `ExampleCardView`, `DotGridView`) are built directly and verified
  manually in the simulator against the UI design in §6.

## 3. Architecture

```
                        ┌──────────────────────────┐
                        │   AppRootView            │
                        │  (@State appVM:          │
                        │   AppShellViewModel)     │
                        └────────────┬─────────────┘
                                     │
                  state: loading     │     state: failed(msg)
                  state: failed(msg) │      ┌─────────────────────┐
                                     │      │ ModelLoadingView    │
                                     ▼      │  logo               │
                          ┌──────────────────┤  ⚠ <error message>  │
                           │ ModelLoadingView │  [ Try again ]      │
                           │  logo            └─────────────────────┘
                           │  "Loading model…"
                           │  ProgressView()
                           │  .task: appVM.bootstrap()
                           │   ↳ loadModel()
                           │   ↳ predictNextTokens(prompt,         topK: 4) → example
                           │   ↳ state = .ready(hasSeenOnboarding: …)
                           └──────────────┬───────────────────────────────┘
                                          │
                           state: ready(  │
                           hasSeenOnboarding:  │
                               false)         │  hasSeenOnboarding: true
                                          │   │
                           ┌──────────────▼─┐ ┌▼──────────────────────┐
                           │ OnboardingFlowView│ │ LevelShellView      │
                           │  OnboardingVM    │ │  Level1Session      │
                           │   .example       │ │   → Level1View      │
                           │   .challengeIntro│ │  (no bootstrap —    │
                           │                  │ │   model is ready)   │
                           │ Example pre-pop  │ └─────────────────────┘
                           │ from appVM.      │
                           │ example          │
                           └──────────────────┘
```

### 3.1 Key invariants

- **The model is loaded exactly once per app launch.** `AppShellViewModel`
  is the sole owner. `OnboardingViewModel` and `Level1Session` do not
  call `service.loadModel()`. `LevelShellView` does not bootstrap.
- **The onboarding example is pre-fetched during model loading.**
  The user sees a single continuous loading screen that covers the
  entire bootstrap. There is no in-onboarding loading state.
- **All load-time errors land in `ModelLoadingView`.** In-game errors
  (e.g., `Level1ViewModel.errorBanner` for a failed `predictNextTokens`
  call mid-play) are a separate, pre-existing pattern and stay as-is.
- **Onboarding is structurally different from Level 1.** No input
  field, no send button, no inspiration chips, no submit counter, no
  best-record chip, no error banner, no pass celebration. The two
  views share zero UI primitives.

## 4. Files

### 4.1 To create

```
llm-visualizer/
├── Models/
│   └── OnboardingExample.swift        # struct OnboardingExample { prompt: String, candidates: [TokenCandidate] }
├── Services/                          # (no new files)
├── ViewModels/
│   └── AppShellViewModel.swift        # loading/failed/ready state machine
└── Views/
    ├── Loading/
    │   └── ModelLoadingView.swift     # logo + "Loading model…" / error + retry
    └── Onboarding/
        └── ExampleCardView.swift      # prompt + DotGridView + caption
                                      # (DotGridView is a private struct in the same file)
```

The `OnboardingViewModel.Step` enum (the 3-step state machine for
onboarding) is a nested type inside `OnboardingViewModel` — it does
not need its own file.

### 4.2 To delete

```
llm-visualizer/
├── Models/
│   └── OnboardingState.swift          # old OnboardingPhase + playsSoFar/bestSoFar — replaced by OnboardingExample + nested OnboardingViewModel.Step
└── Views/
    └── Onboarding/
        ├── FreePlayView.swift         # duplicate of Level 1 input UI — gone
        └── OpeningView.swift          # pre-canned example — replaced by ExampleCardView
```

Plus the corresponding test files for the deleted sources:
`OnboardingStateTests.swift`, `FreePlayView`-related test references
inside `OnboardingViewModelTests` (rewrite the test file).

### 4.3 To modify

- `llm-visualizer/llm_visualizerApp.swift` — no change (still
  hosts `AppRootView`).
- `llm-visualizer/AppRootView.swift` — switch body on
  `appShellVM.state`: loading/failed → `ModelLoadingView`,
  ready(false) → `OnboardingFlowView`, ready(true) → `LevelShellView`.
  Construct `AppShellViewModel` with `LLMService()` (real) or
  `MockLLMService` (test).
- `llm-visualizer/ViewModels/OnboardingViewModel.swift` — full rewrite:
  holds one `OnboardingExample`, holds `step: OnboardingViewModel.Step`
  (nested enum, `.example` / `.challengeIntro`), exposes `goNext()` and
  `acceptChallenge(onComplete:)`. No `service`, no `modelState`,
  no `bootstrap()`.
- `llm-visualizer/Views/Onboarding/OnboardingFlowView.swift` — remove
  `.task { viewModel.bootstrap() }`. Construct `OnboardingViewModel`
  with the single pre-fetched example passed in from `AppRootView`.
  `switch viewModel.step` to choose between `ExampleCardView`
  (×1) and `ChallengeIntroView`.
- `llm-visualizer/Views/LevelShell/LevelShellView.swift` — remove
  `currentSession.bootstrap()` from `.task`. The model is guaranteed
  loaded by the time we get here.
- `llm-visualizer/Models/Level1Session.swift` — remove `bootstrap()`
  method.
- `llm-visualizer/Resources/Localizable.xcstrings` — add
  `"Loading model…"` (`loading.model`), the onboarding prompt
  (`onboarding.prompt`), the example caption
  (`onboarding.example.caption`), and a `"Try again"` (`error.retry`)
  string. Both `en` and `zh-Hans`.

## 5. Components

### 5.0 `OnboardingExample` (new model)

```swift
struct OnboardingExample: Equatable, Sendable {
    let prompt: String
    let candidates: [TokenCandidate]
}
```

Bundles a pre-canned prompt with its pre-fetched top-K candidate
distribution. The prompt and the candidates are produced together
during `AppShellViewModel.bootstrap()` — keeping them in one struct
avoids the risk of the prompt text and the candidate list drifting
out of sync. Held by `AppShellViewModel.example` and passed by
value into `OnboardingViewModel`'s initializer.

No unit test (pure data type with no behavior).

### 5.1 `AppShellViewModel`

```swift
@MainActor
@Observable
final class AppShellViewModel {
    enum State: Equatable {
        case loading
        case failed(String)                       // error.localizedDescription
        case ready(hasSeenOnboarding: Bool)
    }

    var state: State = .loading
    let service: LLMServiceProtocol
    private let onboardingPrompt: String

    private(set) var example: OnboardingExample?

    init(
        service: LLMServiceProtocol,
        progressStore: ProgressStore = .shared,
        onboardingPrompt: String
    ) {
        self.service = service
        self.progressStore = progressStore
        self.onboardingPrompt = onboardingPrompt
    }

    /// Loads the model and pre-fetches the onboarding example.
    /// Transitions: .loading → .ready on success, .loading → .failed on any throw.
    func bootstrap() async { … }

    /// Re-runs the full bootstrap sequence.
    func retry() async { await bootstrap() }

    /// Called by OnboardingFlowView when the user accepts the challenge.
    /// Flips state to .ready(hasSeenOnboarding: true) so AppRootView
    /// re-routes to LevelShellView.
    func markOnboardingComplete() {
        if case .ready = state {
            state = .ready(hasSeenOnboarding: true)
        }
    }
}
```

**Test contract** (`AppShellViewModelTests`, TDD):

- `bootstrap()` transitions `.loading → .ready(hasSeenOnboarding: true)`
  when `MockLLMService` is configured for success and
  `ProgressStore.hasSeenOnboarding = true`.
- `bootstrap()` transitions `.loading → .ready(hasSeenOnboarding: false)`
  when `ProgressStore.hasSeenOnboarding = false`.
- `bootstrap()` populates `example` with an `OnboardingExample`
  whose `prompt` equals the `onboardingPrompt` passed to `init` and
  whose `candidates` matches the values returned by
  `service.predictNextTokens`.
- `bootstrap()` transitions `.loading → .failed(message)` when
  `service.loadModel()` throws; the message equals
  `error.localizedDescription`.
- `bootstrap()` transitions `.loading → .failed(message)` when
  `service.predictNextTokens` (any call) throws.
- `retry()` re-runs the full sequence and reaches `.ready` from a
  prior `.failed` state.
- `retry()` is a no-op (does not crash) when called from `.ready`.
- `markOnboardingComplete()` transitions
  `.ready(hasSeenOnboarding: false)` → `.ready(hasSeenOnboarding: true)`.
- `markOnboardingComplete()` from `.loading` or `.failed` is a no-op.

### 5.2 `ModelLoadingView`

```swift
struct ModelLoadingView: View {
    let state: AppShellViewModel.State
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            logo
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            Text("Loading model…")
            ProgressView()
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        case .ready:
            EmptyView()       // never reached — AppRootView routes around
        }
    }
}
```

The `logo` slot is a placeholder (`Image(systemName: "circle.hexagongrid.fill")`
or a text lockup). A real logo asset is out of scope for this slice.

**No unit test.** Built directly and verified manually against the
UI design in §6.1.

### 5.3 `ExampleCardView`

```swift
struct ExampleCardView: View {
    let prompt: String
    let candidates: [TokenCandidate]
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt)
                .font(.title3.weight(.semibold))
            DotGridView(candidates: candidates)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
```

The card has **no Next button** — the Next button is owned by
`OnboardingFlowView` (the orchestrator) so it can advance
`OnboardingViewModel.step`. This keeps the card pure-presentational.

**No unit test.** Built directly and verified manually against the
UI design in §6.2.

### 5.4 `DotGridView` (private to `ExampleCardView.swift`)

A 10×10 grid of small filled circles. The top-K candidates each
"claim" `round(probability × 100)` circles, in descending order,
rendered left-to-right, top-to-bottom. Overflow (rounding) goes to
the last candidate. Unclaimed circles render in `.quaternary` gray.

```swift
private struct DotGridView: View {
    let candidates: [TokenCandidate]
    private let columns = Array(repeating: GridItem(.fixed(10), spacing: 4), count: 10)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<100, id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(width: 10, height: 10)
            }
        }
    }
    // color(for:) picks the candidate that claims the given dot index
}
```

Color palette: top-1 → green, top-2 → amber, top-3 → orange, top-4 →
red, unclaimed → `Color.gray.opacity(0.15)`.

**No unit test.** Manual verification only.

### 5.5 `OnboardingViewModel` (rewritten)

```swift
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step { case example, challengeIntro }
    var step: Step = .example

    let example: OnboardingExample

    init(example: OnboardingExample) {
        self.example = example
    }

    func goNext() {
        switch step {
        case .example:        step = .challengeIntro
        case .challengeIntro: break
        }
    }

    func acceptChallenge(onComplete: () -> Void) {
        ProgressStore.shared.hasSeenOnboarding = true
        onComplete()
    }
}
```

The `Step` enum is nested inside `OnboardingViewModel` — it has no
behavior worth promoting to its own file.

**Test contract** (`OnboardingViewModelTests`, rewrite, TDD):

- `init` stores `example`.
- Initial `step == .example`.
- `goNext()` from `.example` → `.challengeIntro`.
- `goNext()` from `.challengeIntro` is a no-op.
- `acceptChallenge(onComplete:)` sets
  `ProgressStore.shared.hasSeenOnboarding = true` and invokes
  `onComplete()` exactly once.

### 5.6 `AppRootView` (modified)

```swift
struct AppRootView: View {
    @State private var appVM = AppShellViewModel(
        service: LLMService(),
        onboardingPrompt: String(
            localized: "onboarding.prompt",
            defaultValue: "今天天气真"
        )
    )

    var body: some View {
        Group {
            switch appVM.state {
            case .loading, .failed:
                ModelLoadingView(
                    state: appVM.state,
                    onRetry: { Task { await appVM.retry() } }
                )
            case .ready(let hasSeenOnboarding):
                if hasSeenOnboarding {
                    LevelShellView(currentSession: Level1Session(
                        viewModel: Level1ViewModel(service: appVM.service)
                    ))
                } else if let example = appVM.example {
                    OnboardingFlowView(
                        viewModel: OnboardingViewModel(example: example),
                        onComplete: {
                            appVM.markOnboardingComplete()
                        }
                    )
                } else {
                    // Defensive: .ready(false) should always have an example.
                    EmptyView()
                }
            }
        }
        .task {
            // Skip model load during unit/UI tests — Metal doesn't init in simulator.
            // Same guard pattern as LevelShellView.swift:40.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            await appVM.bootstrap()
        }
    }
}
```

The onboarding prompt is resolved via `String(localized:defaultValue:)`
at view init time and passed into `AppShellViewModel.init`. The VM does
not own the prompt — it is app-level configuration. The default value
serves as a fallback if the catalog entry is missing.

`markOnboardingComplete()` on `AppShellViewModel` flips `state` to
`.ready(hasSeenOnboarding: true)` so `AppRootView` re-evaluates. This
avoids having `OnboardingViewModel` re-render the `AppRootView` shell.

The `.task` guard around `bootstrap()` matches the existing pattern
in `LevelShellView.swift:40-41` — without it, the test target crashes
because Metal cannot initialize in the simulator process. The guard
sits at the view call site (not in `bootstrap()`) so data-layer TDD
tests that call `bootstrap()` directly remain unaffected.

## 6. UI Design

### 6.1 `ModelLoadingView`

```
┌──────────────────────────────────────┐
│                                      │
│              [ logo ]                │   ← 80×80pt, centered
│                                      │
│          Loading model…              │   ← 17pt body
│                                      │
│             ⟳ spinner                │   ← ProgressView()
│                                      │
└──────────────────────────────────────┘
```

Failed state:

```
┌──────────────────────────────────────┐
│                                      │
│              [ logo ]                │
│                                      │
│                  ⚠                   │   ← orange triangle
│                                      │
│    <error.localizedDescription>      │   ← 15pt secondary
│                                      │
│           [ Try again ]              │   ← borderedProminent
│                                      │
└──────────────────────────────────────┘
```

### 6.2 `ExampleCardView`

```
┌──────────────────────────────────────┐
│ 今天天气真                            │   ← title3 semibold (localized via "onboarding.prompt")
│                                      │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟢·                 │   ← 100 dots, 10×10 grid
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟢·                 │   ← top-1 = green
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │   ← top-2 = amber
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│ 🟢🟢🟢🟢🟢🟢🟢🟢🟡·                 │
│                                      │
│ These 100 dots are what the model    │   ← subhead secondary (localized via "onboarding.example.caption")
│ on this device really thought. Now   │
│ you try — can you make it more sure? │
└──────────────────────────────────────┘
```

The Next button lives in `OnboardingFlowView`, not in the card.

### 6.3 Onboarding layout

```
┌──────────────────────────────────────┐
│                                      │
│         ExampleCardView              │
│                                      │
│                                      │
│              [ Next → ]              │   ← bottom, full-width capsule
│                                      │
└──────────────────────────────────────┘
```

## 7. Data Flow

### 7.1 App launch — first time

```
llm_visualizerApp
  → AppRootView (creates @State AppShellViewModel
                    with onboardingPrompt resolved from
                    String(localized: "onboarding.prompt", …))
       .task: appVM.bootstrap()
         ├─ service.loadModel()                       (~5s typical for Qwen3-0.6B)
         ├─ service.predictNextTokens(                 (~1–3s)
         │     onboardingPrompt, topK: 4) → example
         └─ state = .ready(hasSeenOnboarding: false)
  → body re-evaluates: state.ready(false)
  → OnboardingFlowView
       OnboardingViewModel(example: appVM.example)
       body: switch viewModel.step {
         case .example:       ExampleCardView(prompt: example.prompt, candidates: example.candidates, caption: …)
         case .challengeIntro: ChallengeIntroView(...)
       }
```

### 7.2 User taps Next through Onboarding

```
goNext()                // OnboardingViewModel
  step = .example → .challengeIntro
  (body re-renders, challenge intro appears)
[Accept]
acceptChallenge(onComplete: swapToLevelShell)
  ProgressStore.hasSeenOnboarding = true
  appVM.markOnboardingComplete()
  onComplete()                 // → AppRootView body re-evaluates
  → state.ready(true) → LevelShellView
```

### 7.3 Model load fails

```
appVM.bootstrap()
  try await service.loadModel() → throws
  catch: state = .failed("Qwen3-0.6B weights not found in bundle")
  → AppRootView body re-evaluates: state.failed
  → ModelLoadingView(state: .failed(msg), onRetry: …)
  → user sees: ⚠ <message> [ Try again ]
[Try again]
  appVM.retry() → state = .loading → bootstrap() re-runs
```

### 7.4 Level 1 mid-game error (unchanged)

`Level1ViewModel.submit()` catches the throw and populates
`errorBanner`. `Level1View` shows the red banner for ~3s. This is
out of scope for this slice — the pre-existing pattern is correct
for in-game errors (a single failed prediction does not break the
app), distinct from the bootstrap-time errors this slice addresses.

## 8. State Interactions

| Trigger                                   | State change                                                          |
|-------------------------------------------|-----------------------------------------------------------------------|
| App first launch                          | `appVM.state` = `.loading` → `.ready(hasSeenOnboarding: false)`      |
| App reopen (already seen onboarding)      | `appVM.state` = `.loading` → `.ready(hasSeenOnboarding: true)`       |
| `loadModel()` throws                      | `appVM.state` = `.loading` → `.failed(localizedDescription)`         |
| `predictNextTokens` throws               | same as above                                                         |
| User taps [Try again]                     | `appVM.state` = `.failed(msg)` → `.loading` → (retry path)           |
| User taps Next on example                 | `OnboardingViewModel.step` = `.example` → `.challengeIntro`          |
| User taps Next on `.challengeIntro`       | no-op                                                                |
| User accepts challenge                    | `ProgressStore.hasSeenOnboarding` = true; `appVM.state` → `.ready(true)` |
| User navigates to Level 1 (post-onboarding) | `Level1ViewModel.submit()` is the only error path; `errorBanner` shown for ~3s on failure |

## 9. Localization

New strings in `Resources/Localizable.xcstrings` (en Base + zh-Hans):

| Key                                  | en                                                     | zh-Hans                |
|--------------------------------------|--------------------------------------------------------|------------------------|
| `loading.model`                      | `Loading model…`                                       | `正在载入模型`         |
| `error.retry`                        | `Try again`                                            | `重试`                 |
| `onboarding.prompt`                 | `Today's weather is really`                           | `今天天气真`           |
| `onboarding.example.caption`         | `These 100 dots are what the model on this device really thought. Now you try — can you make it more sure?` | `这 100 个点是本机模型刚才的真实想法。下一关你来试试，看能不能让它更确定。` |

The `onboarding.prompt` key is the text sent to the model **and**
shown to the user on the example card. It is localized so that en users
see the prompt in English and zh-Hans users see it in Chinese —
each in a form natural for the user to read. The LLM's distribution
will reflect how strongly the model handles each language (Qwen3-0.6B
is Chinese-trained, so Chinese prompts give sharper distributions).
This trade-off is honest: the user sees the same prompt that was sent
to the model, in the language they understand.

## 10. Open Questions

None blocking. Logged for completeness:

- **Logo asset.** The `ModelLoadingView` has a logo placeholder. A
  real logo is a design-asset task, deferred to a future slice.
- **Error message localization.** `error.localizedDescription` is
  shown raw. If `LLMService` errors are ever localized, this view
  will pick them up automatically. No additional work in this slice.
- **Bootstrap on Level 1 entry.** `LevelShellView` no longer
  bootstraps. If a future change re-introduces a model swap
  (e.g., for Level 7's `loadModel(name:)`), the bootstrap will
  need to be re-thought — out of scope here.

## 11. Out of Scope (Reminder)

- Levels 2–7. The `LevelRegistry` and `LevelSession` abstractions
  stay as-is.
- `Views/Chat/` (legacy chat, unreferenced from `AppRootView`).
  Deletion is a separate concern.
- TDD for `ModelLoadingView`, `ExampleCardView`, `DotGridView`.
  These are presentational SwiftUI primitives with no branching
  logic worth unit-testing. Verified manually.
- Any on-device / running-locally indicator. The teaching is
  delivered via captions only.
- Replacing `ProbabilityBarsView` (Level 1's bar chart). The new
  `DotGridView` is a separate, Onboarding-only component.

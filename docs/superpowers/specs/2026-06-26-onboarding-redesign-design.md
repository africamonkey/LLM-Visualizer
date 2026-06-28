# Onboarding Redesign — Passive Probability Example + Dedicated Loading Screen

**Date:** 2026-06-26 (revised 2026-06-26)
**Status:** Draft (pending user review)
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+
**Replaces:** §6.2 ("Onboarding flow") of `2026-06-23-onboarding-level1-design.md` and the corresponding implementation slice (commits `bade184`..`90cf046`).

## 1. Goal

The current onboarding's Free Play phase is a near-duplicate of Level 1's input UI. The duplication is real: the two views share ~80% of their body and will diverge in maintenance. This slice restructures Onboarding along two axes:

1. **Remove duplication.** Onboarding no longer mirrors Level 1's play surface. Free Play is deleted; what replaces it is structurally different (passive observation, not active input).
2. **Hide model-loading time behind a dedicated screen.** A new full-screen `ModelLoadingView` owns the entire model bootstrap + onboarding-example pre-fetch, so the user never waits inside an onboarding card.

### 1.1 What Onboarding teaches

Onboarding exists to convey **one** insight to the user, before they enter Level 1:

> **The model doesn't pick one word — it assigns a probability to many possible next words.**

Everything in this slice serves this teaching goal. The example card is a single concrete instance of a probability distribution; the caption makes the abstract point explicit; the Level 1 handoff is motivated by it (Level 1 asks the user to find sentences where one word's probability is higher).

### 1.2 What this slice is not

Onboarding is **not** a tutorial that previews Level 1's UI. It is not a "free trial" of Level 1. It does not teach LLM mechanics broadly, language-modeling theory, or tokenization. Those can land in later levels. This slice teaches the single insight above, then hands off.

## 2. Scope

**In scope (this slice):**

- New `ModelLoadingView` — full-screen page with logo + "Loading model…" text + spinner, or error message + [Try again] button.
- New `AppShellViewModel` — owns model load + onboarding-example pre-fetch as a single state machine (`loading` / `failed(msg)` / `ready(hasSeenOnboarding)`). One entry point. One retry.
- New `ExampleCardView` — passive card showing a fixed prompt, a sorted list of the model's top candidates with bars and percentages, and a teaching caption. No input.
- Simplified `OnboardingViewModel` — pure state machine over a 2-step enum (`example` / `challengeIntro`). Holds one pre-fetched `OnboardingExample`, no `service`, no `modelState`, no `bootstrap()`, no progress tracking.
- Pre-fetch of **one** onboarding example during model loading (no per-example loading screen).
- Centralize model loading in `AppRootView`. Remove bootstrap calls from `OnboardingFlowView` and `LevelShellView`/`Level1Session`.
- Delete `FreePlayView`, `OpeningView`, and the old `OnboardingState` enum.
- Extend `Localizable.xcstrings` with "Loading model…", the onboarding prompt (shown on the example card AND sent to the model), and the example caption.
- Unit tests (TDD-first per project convention): `AppShellViewModel`, `OnboardingViewModel`.

**Out of scope (this slice, deferred to future slices):**

- "Confidence ≠ correct" or other advanced distribution concepts. The single insight in §1.1 is enough for v1.
- Replacing or augmenting `ProbabilityBarsView` (Level 1's chart). The Onboarding example uses a different visualization (ranked list with bars, all rows equal weight) — see §5.3.
- Resurrecting or deleting `Views/Chat/` (legacy chat, unreferenced from `AppRootView`).
- Levels 2–7. The `LevelRegistry` and `LevelSession` abstractions are unchanged.
- Any "On device" / "Running locally" indicator on the example card. The teaching is done via captions only.
- Friendly / wrapped error messages. The loading view shows `error.localizedDescription` directly.
- TDD: tests cover data-layer state machines and the AppShell pre-fetch; SwiftUI view bodies (`ModelLoadingView`, `ExampleCardView`) are built directly and verified manually against the UI design in §6.

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

- **The model is loaded exactly once per app launch.** `AppShellViewModel` is the sole owner. `OnboardingViewModel` and `Level1Session` do not call `service.loadModel()`. `LevelShellView` does not bootstrap.
- **The onboarding example is pre-fetched during model loading.** The user sees a single continuous loading screen that covers the entire bootstrap. There is no in-onboarding loading state.
- **All load-time errors land in `ModelLoadingView`.** In-game errors (e.g., `Level1ViewModel.errorBanner` for a failed `predictNextTokens` call mid-play) are a separate, pre-existing pattern and stay as-is.
- **Onboarding is structurally different from Level 1.** No input field, no send button, no inspiration chips, no submit counter, no best-record chip, no error banner, no pass celebration. The Onboarding card shows a fixed prompt + distribution; Level 1's `Level1View` shows a text input + distribution. The two share zero view components.

## 4. Files

### 4.1 To create

```
llm-visualizer/
├── Models/
│   └── OnboardingExample.swift           # struct OnboardingExample { prompt, candidates }
├── ViewModels/
│   ├── AppShellViewModel.swift           # loading/failed/ready state machine
│   └── OnboardingViewModel.swift         # holds example + acceptChallenge(onComplete:)
└── Views/
    ├── Loading/
    │   └── ModelLoadingView.swift         # logo + spinner / error + retry
    └── Onboarding/
        ├── ExampleCardView.swift          # prompt + ProbabilityListView (private) + caption
        └── OnboardingFlowView.swift       # wraps ExampleCardView + single "Try it" button
```

`OnboardingViewModel` does not need its own file for an enum anymore — the `Step` state machine was removed when `ChallengeIntroView` was deleted. The VM is now a simple data holder with one method (`acceptChallenge`).

### 4.2 To delete

```
llm-visualizer/
├── Models/
│   └── OnboardingState.swift              # old OnboardingPhase + playsSoFar/bestSoFar
└── Views/
    ├── Common/
    │   └── ChallengeIntroCard.swift      # was the modal body; gone with ChallengeIntroView
    └── Onboarding/
        ├── ChallengeIntroView.swift      # was the intermediate modal between example and Level 1 — gone
        ├── FreePlayView.swift             # duplicate of Level 1 input UI — gone
        └── OpeningView.swift              # pre-canned example — replaced by ExampleCardView
```

Plus the test file `OnboardingStateTests.swift`.

### 4.3 To modify

- `llm-visualizer/llm_visualizerApp.swift` — no change (still hosts `AppRootView`).
- `llm-visualizer/AppRootView.swift` — switch body on `appVM.state`; construct `OnboardingViewModel` from prefetched example; resolve `onboardingPrompt` from `Localizable.xcstrings` at init time.
- `llm-visualizer/ViewModels/OnboardingViewModel.swift` — full rewrite: holds one `OnboardingExample`, exposes `acceptChallenge(onComplete:)`. No `Step` enum, no `goNext()`, no `service`, no `modelState`, no `bootstrap()`.
- `llm-visualizer/Views/Onboarding/OnboardingFlowView.swift` — renders `ExampleCardView` directly with a single `Try it` button (no `switch` on step, no intermediate `ChallengeIntroView`).
- `llm-visualizer/Views/LevelShell/LevelShellView.swift` — remove `currentSession.bootstrap()` from `.task`. The model is guaranteed loaded by the time we get here.
- `llm-visualizer/Models/Level1Session.swift` — remove `bootstrap()` method.
- `llm-visualizer/Resources/Localizable.xcstrings` — add `loading.model`, `error.retry`, `onboarding.prompt`, `onboarding.example.caption`, `onboarding.tryIt`. The earlier `challenge.body` and `onboarding.next` keys are deprecated (see §9).

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
    private let progressStore: ProgressStore
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
        if case .ready(let hasSeen) = state, !hasSeen {
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
  `service.predictNextTokens` throws.
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

    private var logo: some View {
        Image(systemName: "circle.hexagongrid.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .foregroundStyle(.tint)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            Text("Loading model…")
                .font(.body)
                .foregroundStyle(.secondary)
            ProgressView()
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        case .ready:
            EmptyView()  // unreachable — AppRootView routes around
        }
    }
}
```

The logo slot is a placeholder (`Image(systemName: "circle.hexagongrid.fill")`).
A real logo is a future design-asset task.

**No unit test.** Built directly and verified manually.

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
            ProbabilityListView(candidates: candidates)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

The card has **no Next button** — that lives in `OnboardingFlowView` so
the orchestrator can advance `OnboardingViewModel.step`.

**No unit test.** Built directly and verified manually.

#### 5.3.1 `ProbabilityListView` (private)

A vertical list of the model's top candidates. Each row has a token
label, a horizontal bar whose width is proportional to the candidate's
probability, and the percentage as text. All rows use the same visual
style — there is no spotlight on the top candidate. The teaching
goal is the **distribution**, not the winner; equal-weight rows
reinforce that every row is a real possibility the model considered.

```swift
private struct ProbabilityListView: View {

    let candidates: [TokenCandidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(candidates.prefix(4).enumerated()), id: \.offset) { _, c in
                ProbabilityRow(token: c.text, probability: c.probability)
            }
        }
    }
}

private struct ProbabilityRow: View {

    let token: String
    let probability: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(token)
                .font(.body.monospaced())
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: probability))
                        .frame(width: geo.size.width * CGFloat(probability))
                }
            }
            .frame(height: 12)
            Text("\(Int((probability * 100).rounded()))%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func color(for probability: Double) -> Color {
        switch probability {
        case 0.50...: return .green
        case 0.25..<0.50: return .orange
        case 0.10..<0.25: return .yellow
        default: return .red
        }
    }
}
```

**Color bands** are thresholds on the candidate's own probability,
not on its rank: top-1 with 12% probability gets red; rank-2 with
40% probability gets orange. This reinforces "the rank isn't the
point — the magnitude is."

**No unit test.** Built directly and verified manually.

#### 5.3.2 Why a ranked list, not a chart

A ranked list with bars and percentages is the simplest honest
visualization of a probability distribution:

- A reader needs no legend to interpret "the model is more sure about
  this word."
- The numbers (0–100%) are immediately readable; no arbitrary
  metaphor (no "100 dots", no "pie slices", no abstract shapes).
- The visualization is **structurally distinct** from Level 1's
  `ProbabilityBarsView`, which spotlights top-1 as a large card and
  compresses the rest. The Onboarding list treats all rows equally
  to emphasize the distribution itself.

### 5.4 `OnboardingViewModel` (rewritten)

```swift
@MainActor
@Observable
final class OnboardingViewModel {

    let example: OnboardingExample

    private let progressStore: ProgressStore

    init(
        example: OnboardingExample,
        progressStore: ProgressStore = .shared
    ) {
        self.example = example
        self.progressStore = progressStore
    }

    func acceptChallenge(onComplete: @escaping () -> Void) {
        progressStore.hasSeenOnboarding = true
        onComplete()
    }
}
```

There is no longer a `Step` enum or `goNext()` method — the single
`acceptChallenge(onComplete:)` does the only thing OnboardingFlowView
needs: persist `hasSeenOnboarding = true`, then invoke the
caller's completion closure.

**Test contract** (`OnboardingViewModelTests`, rewrite, TDD):

- `init` stores `example`.
- `acceptChallenge(onComplete:)` sets
  `ProgressStore.shared.hasSeenOnboarding = true` and invokes
  `onComplete()` exactly once.

### 5.5 `AppRootView` (modified)

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
            // Same pattern as LevelShellView.swift:40.
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
│ 今天天气真                            │   ← title3 semibold
│                                      │       (localized via "onboarding.prompt")
│ 好       ████████████████░░ 65%      │   ← equal-weight rows,
│ 不错     ████░░░░░░░░░░░░░░ 20%      │       colored by probability band
│ 暖       ██░░░░░░░░░░░░░░░ 8%       │
│ 冷       ░░░░░░░░░░░░░░░░░ 5%       │
│                                      │
│ The model's actual guess — these     │   ← subhead secondary
│ are the words it considered, each     │       (localized via
│ with its own probability. Now you     │        "onboarding.example.caption")
│ try to find a sentence where one      │
│ word clearly wins.                   │
└──────────────────────────────────────┘
```

The "Try it" button lives in `OnboardingFlowView`, not in the card.

### 6.3 Onboarding layout

```
┌──────────────────────────────────────┐
│                                      │
│         ExampleCardView              │
│                                      │
│                                      │
│           [ Try it → ]                │   ← bottom, full-width capsule
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
       body: ExampleCardView(prompt: example.prompt, candidates: example.candidates, caption: …)
             + single "Try it" button
```

### 7.2 User accepts onboarding

```
[Try it]                  // OnboardingFlowView button → viewModel.acceptChallenge(onComplete: onComplete)
  viewModel.acceptChallenge(onComplete: onComplete)
    ProgressStore.hasSeenOnboarding = true
    onComplete()           // → AppRootView's closure runs
                            // → appVM.markOnboardingComplete()
                            // → state.ready(true) → AppRootView body re-evaluates
                            // → LevelShellView
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
| User taps [Try it] on example             | `ProgressStore.hasSeenOnboarding` = true; `appVM.state` → `.ready(true)` |
| User navigates to Level 1 (post-onboarding) | `Level1ViewModel.submit()` is the only error path; `errorBanner` shown for ~3s on failure |

## 9. Localization

New strings in `Resources/Localizable.xcstrings` (en Base + zh-Hans):

| Key                                  | en                                                                                   | zh-Hans                                       |
|--------------------------------------|--------------------------------------------------------------------------------------|-----------------------------------------------|
| `loading.model`                      | `Loading model…`                                                                     | `正在载入模型`                                 |
| `error.retry`                        | `Try again`                                                                          | `重试`                                         |
| `onboarding.prompt`                 | `Today's weather is really`                                                         | `今天天气真`                                   |
| `onboarding.example.caption`         | `The model's actual guess — these are the words it considered, each with its own probability. Now you try to find a sentence where one word clearly wins.` | `模型的真实想法——这几个候选词各有不同的概率。下一关看你能不能让某一个词明显胜出。` |
| `onboarding.tryIt`                   | `Let me try`                                                                         | `我来试一试`                                   |

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
- **Distribution-row count.** The current design shows top-4 candidates.
  Whether 3, 4, or 5 rows is best is an empirical question — a future
  usability pass can iterate on this without touching the data layer
  (the model already returns top-K=4).
- **Should Onboarding return to Level 1 with a "summary" recap?** Once
  the user finishes Level 1, returning to onboarding is gated by
  `ProgressStore.hasSeenOnboarding = true`. There is no in-app way to
  re-watch the onboarding. Whether to add a "Replay onboarding" affordance
  is deferred to a future slice.

## 11. Out of Scope (Reminder)

- Levels 2–7. The `LevelRegistry` and `LevelSession` abstractions
  stay as-is.
- `Views/Chat/` (legacy chat, unreferenced from `AppRootView`).
  Deletion is a separate concern.
- TDD for `ModelLoadingView` and `ExampleCardView`. These are
  presentational SwiftUI primitives with no branching logic worth
  unit-testing. Verified manually.
- Any on-device / running-locally indicator. The teaching is
  delivered via captions only.
- Replacing `ProbabilityBarsView` (Level 1's chart). The new
  `ProbabilityListView` (Onboarding) is structurally distinct — see
  §5.3.2.
- "Confidence ≠ correct" or other advanced distribution concepts
  (§1.1 covers the single insight; advanced concepts land in later
  levels).

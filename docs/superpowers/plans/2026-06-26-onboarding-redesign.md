# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Onboarding-vs-Level 1 duplication by replacing the 3-step onboarding (Opening → Free Play → Challenge Intro) with a single passive example card (followed by the existing Challenge Intro), and hide model loading behind a dedicated full-screen page. Centralize all model bootstrapping in a new `AppShellViewModel` and pre-fetch the onboarding example during that bootstrap, so the user never sees an in-onboarding loading state.

**Architecture:** New `AppShellViewModel` owns the model-load + onboarding-example pre-fetch as a single state machine (`loading` / `failed(msg)` / `ready(hasSeenOnboarding)`). `AppRootView` switches on this state. `ModelLoadingView` is the visual for `.loading` and `.failed`. Onboarding is a single-card passive example flow (`ExampleCardView` with a private `ProbabilityListView`) plus a single "Try it" button that goes directly to Level 1 — no intermediate modal, no state machine in `OnboardingViewModel` (it just holds the example and exposes `acceptChallenge(onComplete:)`). `LevelShellView` and `Level1Session` lose their `bootstrap()` calls (model is guaranteed loaded by the time we get there). TDD-first for all data-layer code; SwiftUI primitives built directly and verified manually.

**Tech Stack:** Swift 5.9+, SwiftUI (`@Observable`, `@Bindable`, `LazyVGrid`), Swift Testing (`@Test`, `#expect`, `@Suite(.serialized)`, `@MainActor`), `LLMServiceProtocol` (with `MockLLMService` for tests), `ProgressStore` (UserDefaults-backed), `Localizable.xcstrings` String Catalog.

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-26-onboarding-redesign-design.md`
- Sibling files for style: `llm-visualizer/Models/TokenCandidate.swift`, `llm-visualizer/ViewModels/OnboardingViewModel.swift` (to be rewritten)
- Sibling tests for style: `llm-visualizerTests/TokenCandidateTests.swift`, `llm-visualizerTests/Level1ViewModelTests.swift`

**Test invocation convention** (used throughout):
```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/<TestClassName>
```

---

## File Structure

**Models (new):**
- `OnboardingExample.swift` — `struct OnboardingExample { prompt, candidates }`

**Models (deleted):**
- `OnboardingState.swift` — old `OnboardingPhase` enum

**Models (modified):**
- `Level1Session.swift` — remove `bootstrap()` method

**ViewModels (new):**
- `AppShellViewModel.swift` — loading/failed/ready state machine

**ViewModels (rewritten):**
- `OnboardingViewModel.swift` — pure 3-step state machine + accept-challenge

**Views (new):**
- `Loading/ModelLoadingView.swift` — logo + spinner / error + retry
- `Onboarding/ExampleCardView.swift` — prompt + ProbabilityListView (private, same file) + caption

**Views (modified):**
- `Onboarding/OnboardingFlowView.swift` — render `ExampleCardView` plus a single "Try it" button (no `Step` switch, no intermediate modal)
- `AppRootView.swift` — switch on `appVM.state`; construct `OnboardingViewModel` from the single prefetched example
- `LevelShell/LevelShellView.swift` — remove `.task { ... bootstrap() }` block

**Views (deleted):**
- `Onboarding/FreePlayView.swift`
- `Onboarding/OpeningView.swift`

**Services (modified):**
- `LLMService.swift` — add `predictNextTokensError: Error?` to `MockLLMService` for failure-injection tests

**Localization (modified):**
- `Resources/Localizable.xcstrings` — add `loading.model`, `error.retry`, `onboarding.prompt`, `onboarding.example.caption`, `onboarding.tryIt`. The earlier `challenge.body` and `onboarding.next` keys are deprecated (kept so existing translations aren't orphaned).

**Tests (new):**
- `AppShellViewModelTests.swift`
- (rewrite) `OnboardingViewModelTests.swift`

**Tests (deleted):**
- (none at the file level — the existing `OnboardingViewModelTests.swift` is *rewritten* in place)

**App root (modified):**
- `AppRootView.swift` — see above

---

## Phase 1: Data Layer (TDD)

All data-layer code is TDD-first. Each task: write failing tests → run to confirm fail → implement minimal code → run to confirm pass → commit.

### Task 1: Extend `MockLLMService` with `predictNextTokensError`

`AppShellViewModel`'s error-path tests need a way to make `predictNextTokens` throw. The existing `MockLLMService` already has `loadModelError`; we add an analogous `predictNextTokensError`.

**Files:**
- Modify: `llm-visualizer/Services/LLMService.swift` (the `MockLLMService` class only)
- Create: `llm-visualizerTests/MockLLMServicePredictErrorTests.swift`

- [ ] **Step 1: Write the failing test**

Create `llm-visualizerTests/MockLLMServicePredictErrorTests.swift`:

```swift
//
//  MockLLMServicePredictErrorTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct MockLLMServicePredictErrorTests {

    @Test func predictNextTokensThrowsWhenPredictErrorSet() async {
        let mock = MockLLMService()
        mock.predictNextTokensError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "forced predict failure"]
        )
        do {
            _ = try await mock.predictNextTokens(prompt: "x", topK: 4)
            Issue.record("Expected throw")
        } catch {
            #expect((error as NSError).localizedDescription == "forced predict failure")
        }
    }

    @Test func predictNextTokensReturnsStubWhenNoError() async throws {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "a", probability: 0.5)
        ]
        let result = try await mock.predictNextTokens(prompt: "x", topK: 4)
        #expect(result.count == 1)
        #expect(result.first?.text == "a")
    }
}
```

- [ ] **Step 2: Run the new test to verify it fails**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/MockLLMServicePredictErrorTests
```

Expected: build fails with "Value of type 'MockLLMService' has no member 'predictNextTokensError'".

- [ ] **Step 3: Add the property to `MockLLMService`**

Edit `llm-visualizer/Services/LLMService.swift`. In the `MockLLMService` class, add this property alongside the other `stubbed*` / `*Error` fields (around line 200):

```swift
    var predictNextTokensError: Error?
```

Then modify the `predictNextTokens` method (around line 242) to throw when set:

```swift
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate] {
        if let error = predictNextTokensError { throw error }
        let clamped = max(0, topK)
        return Array(stubbedPredictTopK.prefix(clamped))
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Re-run the same `xcodebuild test` command. Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Services/LLMService.swift \
        llm-visualizerTests/MockLLMServicePredictErrorTests.swift
git commit -m "feat(Service): MockLLMService.predictNextTokensError for failure injection"
```

---

### Task 2: Add `OnboardingExample` struct

Pure data type, no TDD. Mirrors the project's other trivial value types (`TokenCandidate`, etc.).

**Files:**
- Create: `llm-visualizer/Models/OnboardingExample.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  OnboardingExample.swift
//

import Foundation

struct OnboardingExample: Equatable, Sendable {
    let prompt: String
    let candidates: [TokenCandidate]
}
```

- [ ] **Step 2: Verify the project builds**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Models/OnboardingExample.swift
git commit -m "feat(Models): OnboardingExample struct"
```

---

### Task 3: `AppShellViewModel` — State enum + initial state

The first TDD pass: define the `State` enum, the `state` property, and the `init`. Verify the initial state is `.loading`.

**Files:**
- Create: `llm-visualizerTests/AppShellViewModelTests.swift`
- Create: `llm-visualizer/ViewModels/AppShellViewModel.swift`

- [ ] **Step 1: Write the failing test**

Create `llm-visualizerTests/AppShellViewModelTests.swift`:

```swift
//
//  AppShellViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct AppShellViewModelTests {

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
        return ProgressStore(defaults: defaults)
    }

    @Test func initialStateIsLoading() {
        let appVM = AppShellViewModel(
            service: MockLLMService(),
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        #expect(appVM.state == .loading)
        #expect(appVM.example == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/AppShellViewModelTests
```

Expected: build fails with "Cannot find 'AppShellViewModel' in scope".

- [ ] **Step 3: Create `AppShellViewModel` with the State enum and properties**

Create `llm-visualizer/ViewModels/AppShellViewModel.swift`:

```swift
//
//  AppShellViewModel.swift
//

import Foundation

@MainActor
@Observable
final class AppShellViewModel {

    enum State: Equatable {
        case loading
        case failed(String)
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
}
```

- [ ] **Step 4: Run the test to verify it passes**

Re-run the same `xcodebuild test` command. Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/AppShellViewModel.swift \
        llm-visualizerTests/AppShellViewModelTests.swift
git commit -m "feat(AppShell): AppShellViewModel state enum + initial state (TDD)"
```

---

### Task 4: `AppShellViewModel` — bootstrap happy path

Implement the happy path of `bootstrap()`: load the model, pre-fetch the onboarding example using the prompt passed to `init`, transition to `.ready`, and store the result.

**Files:**
- Modify: `llm-visualizerTests/AppShellViewModelTests.swift`
- Modify: `llm-visualizer/ViewModels/AppShellViewModel.swift`

- [ ] **Step 1: Add the failing happy-path tests**

Append to `llm-visualizerTests/AppShellViewModelTests.swift`:

```swift
    @Test func bootstrapHappyPathWhenOnboardingNotSeen() async {
        let store = freshStore()
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.7),
            TokenCandidate(id: 2, text: "不错", probability: 0.2),
        ]
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: store,
            onboardingPrompt: "今天天气真"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        #expect(appVM.example?.prompt == "今天天气真")
        #expect(appVM.example?.candidates.count == 2)
    }

    @Test func bootstrapHappyPathWhenOnboardingAlreadySeen() async {
        let store = freshStore()
        store.hasSeenOnboarding = true
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.5)
        ]
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: store,
            onboardingPrompt: "今天天气真"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: true))
    }
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/AppShellViewModelTests
```

Expected: the two new tests fail (build may pass; the `.ready` assertion is wrong because `bootstrap` doesn't exist yet, and `state` is still `.loading`).

- [ ] **Step 3: Add `bootstrap` to `AppShellViewModel`**

Edit `llm-visualizer/ViewModels/AppShellViewModel.swift`. Add the `bootstrap` method after `init` (no static prompt list — the prompt is injected):

```swift
    func bootstrap() async {
        state = .loading
        do {
            try await service.loadModel()
            let candidates = try await service.predictNextTokens(
                prompt: onboardingPrompt,
                topK: 4
            )
            self.example = OnboardingExample(
                prompt: onboardingPrompt,
                candidates: candidates
            )
            state = .ready(hasSeenOnboarding: progressStore.hasSeenOnboarding)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 3 tests pass (initial + 2 happy-path).

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/AppShellViewModel.swift \
        llm-visualizerTests/AppShellViewModelTests.swift
git commit -m "feat(AppShell): AppShellViewModel bootstrap happy path (TDD)"
```

---

### Task 5: `AppShellViewModel` — bootstrap error handling

Add the two error-path tests: `loadModel` throws, and `predictNextTokens` throws. The `catch` block in `bootstrap` (from Task 4) already handles both — these tests verify it.

**Files:**
- Modify: `llm-visualizerTests/AppShellViewModelTests.swift`

- [ ] **Step 1: Add the failing error-path tests**

Append to `llm-visualizerTests/AppShellViewModelTests.swift`:

```swift
    @Test func bootstrapFailsWhenLoadModelThrows() async {
        let mock = MockLLMService()
        mock.loadModelError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "model not found"]
        )
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .failed("model not found"))
        #expect(appVM.example == nil)
    }

    @Test func bootstrapFailsWhenPredictNextTokensThrows() async {
        let mock = MockLLMService()
        mock.predictNextTokensError = NSError(
            domain: "test", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "forward pass crashed"]
        )
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .failed("forward pass crashed"))
    }
```

- [ ] **Step 2: Run the new tests to verify they pass**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/AppShellViewModelTests
```

Expected: all 5 tests pass (the `catch` block from Task 4 already handles both throw paths — these tests just lock in that behavior).

- [ ] **Step 3: Commit**

```bash
git add llm-visualizerTests/AppShellViewModelTests.swift
git commit -m "test(AppShell): bootstrap error paths (loadModel + predictNextTokens)"
```

> Note: no source change needed in this task — the `catch` block from Task 4 covers both. The task exists to lock the contract with tests.

---

### Task 6: `AppShellViewModel` — retry

Implement `retry()`. Should re-run the full `bootstrap()` sequence, regardless of the current state (with the side-effect-only test for `.ready`).

**Files:**
- Modify: `llm-visualizerTests/AppShellViewModelTests.swift`
- Modify: `llm-visualizer/ViewModels/AppShellViewModel.swift`

- [ ] **Step 1: Add the failing retry tests**

Append to `llm-visualizerTests/AppShellViewModelTests.swift`:

```swift
    @Test func retryFromFailedReachesReady() async {
        let mock = MockLLMService()
        mock.loadModelError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "first call fails"]
        )
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore()
        )
        await appVM.bootstrap()
        #expect(appVM.state == .failed("first call fails"))

        // Clear the error so the next call succeeds.
        mock.loadModelError = nil
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "a", probability: 0.5)
        ]
        await appVM.retry()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        #expect(appVM.example != nil)
    }

    @Test func retryFromReadyIsNoOp() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "a", probability: 0.5)
        ]
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        await appVM.retry()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
    }
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/AppShellViewModelTests
```

Expected: 2 new tests fail with "Value of type 'AppShellViewModel' has no member 'retry'".

- [ ] **Step 3: Implement `retry`**

Edit `llm-visualizer/ViewModels/AppShellViewModel.swift`. Add the method after `bootstrap`:

```swift
    func retry() async {
        await bootstrap()
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/AppShellViewModel.swift \
        llm-visualizerTests/AppShellViewModelTests.swift
git commit -m "feat(AppShell): AppShellViewModel.retry (TDD)"
```

---

### Task 7: `AppShellViewModel` — `markOnboardingComplete`

Implement `markOnboardingComplete()`. Flips `state` from `.ready(hasSeenOnboarding: false)` to `.ready(hasSeenOnboarding: true)`. No-op from other states.

**Files:**
- Modify: `llm-visualizerTests/AppShellViewModelTests.swift`
- Modify: `llm-visualizer/ViewModels/AppShellViewModel.swift`

- [ ] **Step 1: Add the failing tests**

Append to `llm-visualizerTests/AppShellViewModelTests.swift`:

```swift
    @Test func markOnboardingCompleteFlipsReadyFalseToReadyTrue() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.5)
        ]
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        appVM.markOnboardingComplete()
        #expect(appVM.state == .ready(hasSeenOnboarding: true))
    }

    @Test func markOnboardingCompleteFromLoadingIsNoOp() {
        let appVM = AppShellViewModel(
            service: MockLLMService(),
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        #expect(appVM.state == .loading)
        appVM.markOnboardingComplete()
        #expect(appVM.state == .loading)
    }
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/AppShellViewModelTests
```

Expected: 2 new tests fail with "Value of type 'AppShellViewModel' has no member 'markOnboardingComplete'".

- [ ] **Step 3: Implement `markOnboardingComplete`**

Edit `llm-visualizer/ViewModels/AppShellViewModel.swift`. Add after `retry`:

```swift
    func markOnboardingComplete() {
        if case .ready(let hasSeen) = state, !hasSeen {
            state = .ready(hasSeenOnboarding: true)
        }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/AppShellViewModel.swift \
        llm-visualizerTests/AppShellViewModelTests.swift
git commit -m "feat(AppShell): AppShellViewModel.markOnboardingComplete (TDD)"
```

---

### Task 8: `OnboardingViewModel` rewrite — Step enum + init

Replace the existing `OnboardingViewModel` with a slim 2-step state machine. The first TDD pass: define the `Step` enum (`.example` / `.challengeIntro`), the `step` property, the single `example` stored property, and the initializer.

This task **rewrites** `OnboardingViewModelTests.swift` in place. The old test cases reference `phase`, `transitionToFreePlay()`, `recordPlay()`, `showChallengeManually()`, `scheduleAutoShowIfSecondPlay()`, and `bestSoFar` — all of which are removed. The new file has a different shape.

**Files:**
- Rewrite: `llm-visualizer/ViewModels/OnboardingViewModel.swift`
- Rewrite: `llm-visualizerTests/OnboardingViewModelTests.swift`

- [ ] **Step 1: Delete the contents of the old test file and write the new failing tests**

Overwrite `llm-visualizerTests/OnboardingViewModelTests.swift` with:

```swift
//
//  OnboardingViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct OnboardingViewModelTests {

    private let example = OnboardingExample(
        prompt: "今天天气真",
        candidates: [
            TokenCandidate(id: 1, text: "好", probability: 0.85)
        ]
    )

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
        return ProgressStore(defaults: defaults)
    }

    private func makeVM(store: ProgressStore? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            example: example,
            progressStore: store ?? freshStore()
        )
    }

    @Test func initStoresExample() {
        let vm = makeVM()
        #expect(vm.example.prompt == "今天天气真")
        #expect(vm.example.candidates.count == 1)
    }

    @Test func initialStepIsExample() {
        let vm = makeVM()
        #expect(vm.step == .example)
    }
}
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/OnboardingViewModelTests
```

Expected: build fails — `OnboardingViewModel`'s initializer signature no longer matches the new tests, and `Step` no longer exists.

- [ ] **Step 3: Rewrite `OnboardingViewModel`**

Overwrite `llm-visualizer/ViewModels/OnboardingViewModel.swift` with:

```swift
//
//  OnboardingViewModel.swift
//

import Foundation

@MainActor
@Observable
final class OnboardingViewModel {

    enum Step { case example, challengeIntro }
    var step: Step = .example

    let example: OnboardingExample

    private let progressStore: ProgressStore

    init(
        example: OnboardingExample,
        progressStore: ProgressStore = .shared
    ) {
        self.example = example
        self.progressStore = progressStore
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 2 tests pass.

> At this point the project won't fully build (other call sites still reference the old API). That's expected; the rest is fixed in Phase 3.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/OnboardingViewModel.swift \
        llm-visualizerTests/OnboardingViewModelTests.swift
git commit -m "feat(Onboarding): OnboardingViewModel rewritten as 2-step state machine (TDD)"
```

---

> **Task removed.** The `goNext` method and its tests were dropped
> alongside `ChallengeIntroView`. `OnboardingViewModel` no longer
> has a `Step` enum — it just holds the example and exposes
> `acceptChallenge(onComplete:)`. The corresponding step in this
> plan is now **Task 9** below.

---

### Task 9: `OnboardingViewModel` — `acceptChallenge`

Add the `acceptChallenge(onComplete:)` method. Writes `hasSeenOnboarding = true` and invokes the callback.

**Files:**
- Modify: `llm-visualizerTests/OnboardingViewModelTests.swift`
- Modify: `llm-visualizer/ViewModels/OnboardingViewModel.swift`

- [ ] **Step 1: Add the failing test**

Append to `llm-visualizerTests/OnboardingViewModelTests.swift`:

```swift
    @Test func acceptChallengeWritesPersistenceAndInvokesCallback() {
        let store = freshStore()
        let vm = makeVM(store: store)
        var callbackFired = false
        vm.acceptChallenge { callbackFired = true }
        #expect(callbackFired == true)
        #expect(store.hasSeenOnboarding == true)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/OnboardingViewModelTests
```

Expected: fails with "Value of type 'OnboardingViewModel' has no member 'acceptChallenge'".

- [ ] **Step 3: Implement `acceptChallenge`**

Edit `llm-visualizer/ViewModels/OnboardingViewModel.swift`. Add after the `init`:

```swift
    func acceptChallenge(onComplete: @escaping () -> Void) {
        progressStore.hasSeenOnboarding = true
        onComplete()
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Re-run the same `xcodebuild test` command. Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/OnboardingViewModel.swift \
        llm-visualizerTests/OnboardingViewModelTests.swift
git commit -m "feat(Onboarding): OnboardingViewModel.acceptChallenge (TDD)"
```

---

## Phase 2: UI Primitives (no TDD — manual verify)

These views have no branching logic worth unit-testing. Build them directly and verify in the simulator in Phase 4.

### Task 11: `ModelLoadingView`

A full-screen page showing either the loading state (logo + "Loading model…" + spinner) or the error state (logo + warning icon + error message + [Try again] button).

**Files:**
- Create: `llm-visualizer/Views/Loading/ModelLoadingView.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  ModelLoadingView.swift
//

import SwiftUI

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

- [ ] **Step 2: Commit (project won't fully build until Phase 3 lands, but commit the file alone for review)**

```bash
git add llm-visualizer/Views/Loading/ModelLoadingView.swift
git commit -m "feat(Views): ModelLoadingView (logo + spinner / error + retry)"
```

---

### Task 12: `ExampleCardView` (with private `ProbabilityListView`)

Two private structs in one file: the public `ExampleCardView` (prompt + list + caption) and the private `ProbabilityListView` (which renders `ProbabilityRow` rows). The list shows top-4 candidates as equal-weight rows — token label, horizontal bar (width = probability), percentage. Color bands by probability threshold, not by rank.

**Files:**
- Create: `llm-visualizer/Views/Onboarding/ExampleCardView.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  ExampleCardView.swift
//

import SwiftUI

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
        case 0.50...:        return .green
        case 0.25..<0.50:    return .orange
        case 0.10..<0.25:    return .yellow
        default:             return .red
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add llm-visualizer/Views/Onboarding/ExampleCardView.swift
git commit -m "feat(Views): ExampleCardView with ProbabilityListView"
```

---

### ~~Task 13: Update `ChallengeIntroView` to drop `bestSoFar`~~

> **Task removed.** `ChallengeIntroView` and `ChallengeIntroCard`
> were deleted entirely (along with the `bestSoFar` parameter that
> this task addressed). The flow now goes directly from the example
> card to Level 1 via a single "Try it" button — see Task 13 below.

---

### Task 13: Rewrite `OnboardingFlowView` — single button to Level 1

Wrap `ExampleCardView` with a single "Try it" button. Tapping it calls
`viewModel.acceptChallenge(onComplete:)`, which writes persistence and
invokes the `onComplete` closure that AppRootView routes to LevelShellView.

**Files:**
- Modify: `llm-visualizer/Views/Onboarding/OnboardingFlowView.swift`

- [ ] **Step 1: Overwrite the file**

```swift
//
//  OnboardingFlowView.swift
//

import SwiftUI

struct OnboardingFlowView: View {

    let viewModel: OnboardingViewModel
    let onComplete: () -> Void

    init(
        viewModel: OnboardingViewModel,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            ExampleCardView(
                prompt: viewModel.example.prompt,
                candidates: viewModel.example.candidates,
                caption: String(
                    localized: "onboarding.example.caption",
                    defaultValue: "The model's actual guess — these are the words it considered, each with its own probability. Now you try to find a sentence where one word clearly wins."
                )
            )
            tryItButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var tryItButton: some View {
        Button {
            viewModel.acceptChallenge(onComplete: onComplete)
        } label: {
            Text(String(localized: "onboarding.tryIt", defaultValue: "Let me try"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .padding(20)
    }
}
```

Note: `viewModel` is `let`, not `@State`. The VM does not mutate
after init, so `@State` is unnecessary — SwiftUI observes
`@Observable` types regardless of storage.

- [ ] **Step 2: Delete obsolete files**

```bash
git rm llm-visualizer/Views/Onboarding/ChallengeIntroView.swift \
       llm-visualizer/Views/Common/ChallengeIntroCard.swift
```

- [ ] **Step 3: Verify the build still passes**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. (The Xcode project auto-discovers file deletions; no `project.pbxproj` edit needed — see Task 18 for the same pattern.)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(Views): OnboardingFlowView — single button to Level 1"
```

---

## Phase 3: Integration (modify existing call sites)

### ~~Task 14: Rewrite `OnboardingFlowView`~~

> **Task removed.** It was superseded by **Task 13** above, which
> replaces the `Step`-switching version with the single-button version
> that goes directly to Level 1.

---

### Task 14: Rewrite `AppRootView`

Switch the body on `appVM.state` instead of the local `showOnboarding: Bool` flag. The state machine handles the initial onboarding check (via `ProgressStore.hasSeenOnboarding` in `bootstrap`) and the post-onboarding flip (via `markOnboardingComplete`).

**Files:**
- Modify: `llm-visualizer/AppRootView.swift`

- [ ] **Step 1: Overwrite the file**

```swift
//
//  AppRootView.swift
//

import SwiftUI

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

> **Implementation note:** The XCTest guard at the view call site (not
> inside `AppShellViewModel.bootstrap()`) is required because the test
> target links against the main target's compiled module — when the
> main target doesn't compile (because `bootstrap()` triggers
> `LLMService.loadModel()` → Metal init → crash on simulator), the
> test target also fails to load. Without the guard, `xcodebuild test`
> crashes with `Test crashed with signal abrt before establishing
> connection`. The guard sits at the view call site so data-layer
> TDD tests that call `bootstrap()` directly on a fresh `AppShellViewModel`
> remain unaffected (their tests run in a process where the view's
> `.task` modifier never fires).

- [ ] **Step 2: Commit**

```bash
git add llm-visualizer/AppRootView.swift
git commit -m "refactor(App): AppRootView — route on AppShellViewModel state"
```

---

### Task 15: Remove `bootstrap()` from `LevelShellView`

The model is loaded once by `AppShellViewModel.bootstrap()`; the level shell no longer needs to bootstrap.

**Files:**
- Modify: `llm-visualizer/Views/LevelShell/LevelShellView.swift`

- [ ] **Step 1: Remove the `.task` block**

Edit `llm-visualizer/Views/LevelShell/LevelShellView.swift`. The current `.task` block at the bottom of `body` looks like:

```swift
        .task {
            // Skip model load during unit/UI tests — Metal doesn't init in simulator
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            if let level1 = currentSession as? Level1Session {
                await level1.bootstrap()
            }
        }
```

Replace it with the empty modifier:

```swift
        .task {
            // Model is already loaded by AppShellViewModel before we get here.
            // (No-op task keeps SwiftUI's lifecycle behavior identical.)
        }
```

- [ ] **Step 2: Commit**

```bash
git add llm-visualizer/Views/LevelShell/LevelShellView.swift
git commit -m "refactor(Views): LevelShellView no longer bootstraps model"
```

---

### Task 16: Remove `bootstrap()` from `Level1Session`

The shell is the only caller. With it gone, the method is dead.

**Files:**
- Modify: `llm-visualizer/Models/Level1Session.swift`

- [ ] **Step 1: Remove the `bootstrap` method**

Edit `llm-visualizer/Models/Level1Session.swift`. Delete the last method:

```swift
    func bootstrap() async {
        await viewModel.bootstrap()
    }
```

- [ ] **Step 2: Commit**

```bash
git add llm-visualizer/Models/Level1Session.swift
git commit -m "refactor(Models): Level1Session.bootstrap() removed"
```

---

### Task 17: Delete obsolete files

The new design makes `FreePlayView`, `OpeningView`, and the old `OnboardingPhase` enum dead code.

**Files:**
- Delete: `llm-visualizer/Views/Onboarding/FreePlayView.swift`
- Delete: `llm-visualizer/Views/Onboarding/OpeningView.swift`
- Delete: `llm-visualizer/Models/OnboardingState.swift`

- [ ] **Step 1: Delete the files**

```bash
rm llm-visualizer/Views/Onboarding/FreePlayView.swift \
   llm-visualizer/Views/Onboarding/OpeningView.swift \
   llm-visualizer/Models/OnboardingState.swift
```

- [ ] **Step 2: Verify the project builds**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. If not, grep for any remaining references to `FreePlayView`, `OpeningView`, or `OnboardingPhase` and fix them.

- [ ] **Step 3: Run the full unit test suite**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: all existing tests still pass, plus the new `AppShellViewModelTests` (9 tests) and the rewritten `OnboardingViewModelTests` (6 tests).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: delete obsolete FreePlayView, OpeningView, OnboardingState"
```

---

## Phase 4: Localization + Verification

### Task 18: Update `Localizable.xcstrings`

Add new strings for the loading view, the onboarding prompt, the example caption, and the "Try it" button.

**Files:**
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add the new strings**

In the JSON catalog, add entries for these keys (both `en` and `zh-Hans`):

| Key | en | zh-Hans |
|---|---|---|
| `loading.model` | `Loading model…` | `正在载入模型` |
| `error.retry` | `Try again` | `重试` |
| `onboarding.prompt`                 | `Today's weather is really`                                       | `今天天气真`           |
| `onboarding.example.caption`         | `The model's actual guess — these are the words it considered, each with its own probability. Now you try to find a sentence where one word clearly wins.` | `模型的真实想法——这几个候选词各有不同的概率。下一关看你能不能让某一个词明显胜出。` |
| `onboarding.tryIt`                   | `Let me try`                                                                 | `我来试一试`           |

Edit the file directly. The catalog is JSON with a `strings` map; each entry has `comment`, `localizations.en.stringUnit.state` / `localizations.en.stringUnit.value`, and the same for `zh-Hans`.

- [ ] **Step 2: Verify the project builds**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Resources): strings for loading view, onboarding prompt, example caption, Try it button"
```

---

### Task 19: Manual verification in the simulator

TDD covers the data layer; the SwiftUI views and the integrated flow are verified by hand.

- [ ] **Step 1: Run the app in the iPhone 17 simulator**

```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build run
```

(Or open the project in Xcode and hit ⌘R.)

- [ ] **Step 2: First-launch happy path**

Expected:
1. `ModelLoadingView` appears immediately (no flash of onboarding).
2. Logo + "Loading model…" + spinner are visible.
3. After ~5–10s the example card appears, already populated.
4. Read the caption: it states what the dots mean and hands off to Level 1.
5. Tap **Try it** → `LevelShellView` (Level 1) appears directly.

- [ ] **Step 3: Returning-user happy path**

Stop the app. Re-launch. Expected: `ModelLoadingView` briefly, then `LevelShellView` directly (no onboarding).

- [ ] **Step 4: Failure path**

Delete the bundled model directory to force a load failure:

```bash
mv Qwen3-0.6B-4bit-DWQ-053125 /tmp/_qwen_backup
```

Re-launch. Expected: `ModelLoadingView` shows the error message + [Try again] button. Restore the model and tap retry:

```bash
mv /tmp/_qwen_backup Qwen3-0.6B-4bit-DWQ-053125
```

- [ ] **Step 5: Level 1 mid-game error (sanity check)**

Open Level 1, type a prompt, hit send, force-quit the app mid-forward-pass (or use the simulator's "Slow Animations" / "Network Link Conditioner" to keep it under load). Expected: the existing red `errorBanner` shows for ~3s, the user can retry with a different prompt. (Pre-existing behavior — this task only confirms it still works.)

- [ ] **Step 6: Final commit (if any verification fixes were needed)**

If you made any visual tweaks during verification:

```bash
git add -A
git commit -m "fix(Views): polish from manual verification"
```

If nothing needed fixing, skip this step.

---

## Self-Review

**Spec coverage:**

- §3 architecture (AppRootView + AppShellViewModel + ModelLoadingView + OnboardingFlowView + LevelShellView) → Tasks 12–15 ✓
- §3.1 invariants (single model load, pre-fetch the example, errors in loading view, Onboarding ≠ Level 1 structurally) → Tasks 3–7, 11, 14, 15 ✓
- §4 files (4.1 create, 4.2 delete, 4.3 modify) → Tasks 2, 8, 11, 12, 13, 14, 15, 16, 17, 18 ✓
- §5.0 OnboardingExample → Task 2 ✓
- §5.1 AppShellViewModel (state, bootstrap, retry, markOnboardingComplete) → Tasks 3–7 ✓
- §5.2 ModelLoadingView → Task 11 ✓
- §5.3 ExampleCardView + §5.3.1 ProbabilityListView (private) → Task 12 ✓
- §5.4 OnboardingViewModel rewrite → Tasks 8, 9 ✓
- §5.5 AppRootView → Task 14 ✓
- §6 UI design → Tasks 11, 12, 13 (with manual verification in Task 19) ✓
- §7 data flow → Tasks 13, 14 + verification ✓
- §8 state interactions → Tasks 4, 5, 6, 7, 8, 9 (covered by tests) ✓
- §9 localization → Task 18 ✓
- §10 open questions (logo placeholder, error localization) → Task 11 uses system icon as placeholder, Task 18 uses `error.localizedDescription` via the VM ✓

**Placeholder scan:** No `TBD`/`TODO`/`fill in` markers.

**Type consistency:**
- `AppShellViewModel.State` is referenced as `AppShellViewModel.State` in `ModelLoadingView` and `AppRootView` — defined in Task 3, used in Tasks 11, 14 ✓
- `OnboardingExample` is referenced in `AppShellViewModel.example`, `OnboardingViewModel` init, and `OnboardingFlowView` — defined in Task 2, used in Tasks 4, 8, 13, 14 ✓
- `bootstrap()`, `retry()`, `markOnboardingComplete()` are all public on `AppShellViewModel` — defined Tasks 4, 6, 7, used Task 14 ✓
- `acceptChallenge(onComplete:)` is public on `OnboardingViewModel` — defined Task 9, used Task 13 ✓

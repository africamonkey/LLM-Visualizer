# Onboarding Flow + Level 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a level-based LLM-visualization mode with a 3-step onboarding that primes users to notice model certainty, plus Level 1 (find an input where the model is >90% confident about the next token). Installs a minimal `Level` abstraction so future levels can be added one at a time.

**Architecture:** MVVM with `@MainActor @Observable` view models. One new `LLMService.predictNextTokens(prompt:topK:)` does a single forward pass + softmax + top-K (no sampling). App root is a small router that toggles between `OnboardingFlowView` (first-launch only, gated by `ProgressStore.hasSeenOnboarding`) and `LevelShellView` (wraps current level with header + pass overlay). TDD for all data-layer code; SwiftUI primitives built directly and verified manually against the brainstorming mockups.

**Tech Stack:** Swift 5.9+, SwiftUI (`@Observable`, `NavigationStack`, `.sheet`), MLX (`MLXArray`, `softmax`, `topk`), `MLXLMCommon` (`UserInput`, `Chat.Message`), Swift Testing (`@Test`, `#expect`), `Localizable.xcstrings` String Catalog.

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-23-onboarding-level1-design.md`
- Brainstorming mockups: `.superpowers/brainstorm/18686-1782225140/content/{probability-bars,screen-layout,success-state}.html`
- Sibling files for style: `llm-visualizer/ViewModels/ChatViewModel.swift`, `llm-visualizer/Models/Message.swift`
- Sibling tests for style: `llm-visualizerTests/MessageTests.swift`, `llm-visualizerTests/MockLLMServiceTests.swift`

**Test invocation convention:**
```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/<TestClassName>
```

---

## File Structure

**Models (new):**
- `TokenCandidate.swift` — struct returned by `predictNextTokens`
- `LevelProgress.swift` — `ProgressStore` (UserDefaults)
- `Levels.swift` — `LevelSession` base + `LevelRegistry`
- `OnboardingState.swift` — `OnboardingPhase` enum

**Services (modified):**
- `LLMService.swift` — add `predictNextTokens` to protocol + both impls

**ViewModels (new):**
- `OnboardingViewModel.swift` — onboarding state machine
- `Level1ViewModel.swift` — Level 1 play state

**Views (new):**
- `Onboarding/OnboardingFlowView.swift` — orchestrator
- `Onboarding/OpeningView.swift` — pre-canned example screen
- `Onboarding/FreePlayView.swift` — input + bars + narrator
- `Onboarding/ChallengeIntroView.swift` — modal card
- `LevelShell/LevelShellView.swift` — header + content + pass overlay
- `LevelShell/PassCelebrationView.swift` — full-screen celebration
- `Level1/Level1View.swift` — input + bars + submit + best-record
- `Level1/ProbabilityBarsView.swift` — Top-1 card + Top-3 rows
- `Level1/NarratorLineView.swift` — italic one-liner
- `Common/InspirationButtonsView.swift` — horizontal chip row
- `Common/ChallengeIntroCard.swift` — title + body + CTA
- `Common/LevelHeaderView.swift` — title + goal + best

**App root (modified):**
- `llm_visualizerApp.swift` — swap `ChatView` for `AppRootView`

**Localization (modified):**
- `Resources/Localizable.xcstrings` — add L1 strings

**Chat (untouched, preserved):**
- `Views/Chat/*.swift`, `ViewModels/ChatViewModel.swift` — kept on disk, unreferenced.

**Tests (new):**
- `TokenCandidateTests.swift`
- `LevelProgressTests.swift`
- `LevelRegistryTests.swift`
- `OnboardingViewModelTests.swift`
- `LLMServicePredictTests.swift`
- `Level1ViewModelTests.swift`

---

## Phase 1: Foundation (Tasks 1–7)

Tasks 1–4 are pure-data TDD. Tasks 5–7 introduce the new `LLMService` capability and the L1 view-model; all driven by tests.

### Task 1: `TokenCandidate`

**Files:**
- Create: `llm-visualizer/Models/TokenCandidate.swift`
- Create: `llm-visualizerTests/TokenCandidateTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/TokenCandidateTests.swift`:

```swift
//
//  TokenCandidateTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

struct TokenCandidateTests {

    @Test func storesAllFields() {
        let c = TokenCandidate(id: 42, text: "好", probability: 0.32)
        #expect(c.id == 42)
        #expect(c.text == "好")
        #expect(c.probability == 0.32)
    }

    @Test func equality() {
        let a = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let b = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let c = TokenCandidate(id: 2, text: "x", probability: 0.5)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func hashableForSetUse() {
        let a = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let b = TokenCandidate(id: 1, text: "x", probability: 0.5)
        let set: Set<TokenCandidate> = [a, b]
        #expect(set.count == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/TokenCandidateTests
```

Expected: `** TEST BUILD FAILED **` with "Cannot find 'TokenCandidate' in scope".

- [ ] **Step 3: Implement `TokenCandidate`**

Create `llm-visualizer/Models/TokenCandidate.swift`:

```swift
//
//  TokenCandidate.swift
//

import Foundation

struct TokenCandidate: Sendable, Equatable, Hashable, Identifiable {
    let id: Int
    let text: String
    let probability: Double
}
```

- [ ] **Step 4: Run tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Models/TokenCandidate.swift \
        llm-visualizerTests/TokenCandidateTests.swift
git commit -m "feat(Models): TokenCandidate struct (TDD)"
```

---

### Task 2: `ProgressStore`

**Files:**
- Create: `llm-visualizer/Models/LevelProgress.swift`
- Create: `llm-visualizerTests/LevelProgressTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/LevelProgressTests.swift`:

```swift
//
//  LevelProgressTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
struct LevelProgressTests {

    private func freshStore() -> ProgressStore {
        let suiteName = "llmviz.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return ProgressStore(defaults: defaults)
    }

    @Test func hasSeenOnboardingDefaultsFalse() {
        let store = freshStore()
        #expect(store.hasSeenOnboarding == false)
    }

    @Test func hasSeenOnboardingRoundTrip() {
        let store = freshStore()
        store.hasSeenOnboarding = true
        #expect(store.hasSeenOnboarding == true)
    }

    @Test func levelCompletionDefaultsFalse() {
        let store = freshStore()
        #expect(store.isComplete(1) == false)
    }

    @Test func levelCompletionRoundTrip() {
        let store = freshStore()
        store.setComplete(1, true)
        #expect(store.isComplete(1) == true)
    }

    @Test func setCompleteFalseRemoves() {
        let store = freshStore()
        store.setComplete(1, true)
        store.setComplete(1, false)
        #expect(store.isComplete(1) == false)
    }

    @Test func multipleLevelsAreIndependent() {
        let store = freshStore()
        store.setComplete(1, true)
        store.setComplete(7, true)
        #expect(store.isComplete(1))
        #expect(store.isComplete(7))
        #expect(!store.isComplete(2))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/LevelProgressTests
```

Expected: build fails, "Cannot find 'ProgressStore' in scope".

- [ ] **Step 3: Implement `ProgressStore`**

Create `llm-visualizer/Models/LevelProgress.swift`:

```swift
//
//  LevelProgress.swift
//

import Foundation

final class ProgressStore: @unchecked Sendable {

    static let shared = ProgressStore(defaults: .standard)

    private let defaults: UserDefaults
    private let seenOnboardingKey = "llmviz.hasSeenOnboarding"
    private let completedKey = "llmviz.completedLevels"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: seenOnboardingKey) }
        set { defaults.set(newValue, forKey: seenOnboardingKey) }
    }

    func isComplete(_ levelId: Int) -> Bool {
        completedLevels.contains(levelId)
    }

    func setComplete(_ levelId: Int, _ value: Bool) {
        var set = completedLevels
        if value {
            set.insert(levelId)
        } else {
            set.remove(levelId)
        }
        defaults.set(Array(set).sorted(), forKey: completedKey)
    }

    private var completedLevels: Set<Int> {
        Set((defaults.array(forKey: completedKey) as? [Int]) ?? [])
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Models/LevelProgress.swift \
        llm-visualizerTests/LevelProgressTests.swift
git commit -m "feat(Models): ProgressStore (TDD)"
```

---

### Task 3: `LevelSession` base + `LevelRegistry`

**Files:**
- Create: `llm-visualizer/Models/Levels.swift`
- Create: `llm-visualizerTests/LevelRegistryTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/LevelRegistryTests.swift`:

```swift
//
//  LevelRegistryTests.swift
//

import Foundation
import SwiftUI
import Testing
@testable import llm_visualizer

private final class StubSession: LevelSession {
    var evaluateCallCount = 0
    override init(id: Int, title: String, subtitle: String, goalDescription: String) {
        super.init(id: id, title: title, subtitle: subtitle, goalDescription: goalDescription)
    }
    override func makeContentView() -> AnyView {
        AnyView(Text("stub"))
    }
    override func evaluate() {
        evaluateCallCount += 1
        isComplete = true
    }
}

@Suite(.serialized)
struct LevelRegistryTests {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
    }

    @Test func isCompleteDefaultsFalse() {
        ProgressStore.shared  // touch to compile
        let store = ProgressStore(defaults: freshDefaults())
        let s = StubSession(id: 1, title: "t", subtitle: "s", goalDescription: "g")
        _ = store  // silence unused warning if any
        #expect(s.isComplete == false)
    }

    @MainActor
    @Test func evaluateMarksComplete() {
        let store = ProgressStore(defaults: freshDefaults())
        _ = store
        let s = StubSession(id: 1, title: "t", subtitle: "s", goalDescription: "g")
        #expect(s.evaluateCallCount == 0)
        s.evaluate()
        #expect(s.evaluateCallCount == 1)
        #expect(s.isComplete == true)
    }

    @Test func registryContainsAtLeastOne() {
        #expect(LevelRegistry.all.count >= 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/LevelRegistryTests
```

Expected: build fails, "Cannot find 'LevelSession' in scope".

- [ ] **Step 3: Implement `LevelSession` + `LevelRegistry`**

Create `llm-visualizer/Models/Levels.swift`:

```swift
//
//  Levels.swift
//

import SwiftUI

@MainActor
@Observable
class LevelSession {
    let id: Int
    let title: String
    let subtitle: String
    let goalDescription: String

    var isComplete: Bool {
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

    /// Subclasses override to check if the goal has been met and
    /// mutate `isComplete` accordingly. Default: no-op.
    func evaluate() {}
}

enum LevelRegistry {
    /// Ordered list of level classes. App picks the first
    /// not-yet-complete one as the current level. Future slices
    /// append entries here.
    static let all: [LevelSession.Type] = [
        // Level1Session.self  // uncommented in Task 19
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Models/Levels.swift \
        llm-visualizerTests/LevelRegistryTests.swift
git commit -m "feat(Models): LevelSession base + LevelRegistry (TDD)"
```

---

### Task 4: `OnboardingPhase` + `OnboardingViewModel`

**Files:**
- Create: `llm-visualizer/Models/OnboardingState.swift`
- Create: `llm-visualizer/ViewModels/OnboardingViewModel.swift`
- Create: `llm-visualizerTests/OnboardingViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/OnboardingViewModelTests.swift`:

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

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
    }

    private func makeVM() -> OnboardingViewModel {
        ProgressStore.shared  // keep linker happy
        return OnboardingViewModel(service: MockLLMService())
    }

    @Test func initialPhaseIsOpening() {
        let vm = makeVM()
        #expect(vm.phase == .opening)
    }

    @Test func bestSoFarStartsAtZero() {
        let vm = makeVM()
        #expect(vm.bestSoFar == 0.0)
    }

    @Test func recordPlayBumpsCount() {
        let vm = makeVM()
        vm.transitionToFreePlay()
        vm.recordPlay(top1Probability: 0.32)
        #expect(vm.phase == .freePlay(playsSoFar: 1))
        #expect(vm.bestSoFar == 0.32)
    }

    @Test func recordPlayUpdatesBestSoFar() {
        let vm = makeVM()
        vm.transitionToFreePlay()
        vm.recordPlay(top1Probability: 0.10)
        vm.recordPlay(top1Probability: 0.55)
        vm.recordPlay(top1Probability: 0.30)
        #expect(vm.bestSoFar == 0.55)
    }

    @Test func showChallengeManuallyJumpsToIntro() {
        let vm = makeVM()
        vm.transitionToFreePlay()
        vm.showChallengeManually()
        #expect(vm.phase == .challengeIntro)
    }

    @Test func acceptChallengeWritesPersistenceAndInvokesCallback() {
        let defaults = freshDefaults()
        let store = ProgressStore(defaults: defaults)
        _ = store  // ensure init
        let vm = OnboardingViewModel(
            service: MockLLMService(),
            progressStore: ProgressStore(defaults: defaults)
        )
        var callbackFired = false
        vm.acceptChallenge { callbackFired = true }
        #expect(callbackFired == true)
        #expect(ProgressStore(defaults: defaults).hasSeenOnboarding == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/OnboardingViewModelTests
```

Expected: build fails, "Cannot find 'OnboardingViewModel' in scope".

- [ ] **Step 3: Implement `OnboardingPhase`**

Create `llm-visualizer/Models/OnboardingState.swift`:

```swift
//
//  OnboardingState.swift
//

import Foundation

enum OnboardingPhase: Equatable {
    case opening
    case freePlay(playsSoFar: Int)
    case challengeIntro
}
```

- [ ] **Step 4: Implement `OnboardingViewModel`**

Create `llm-visualizer/ViewModels/OnboardingViewModel.swift`:

```swift
//
//  OnboardingViewModel.swift
//

import Foundation
import MLXLMCommon
import os

@MainActor
@Observable
final class OnboardingViewModel {

    enum ModelState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    var phase: OnboardingPhase = .opening
    var modelState: ModelState = .idle
    private(set) var bestSoFar: Double = 0.0

    private let service: LLMServiceProtocol
    private let progressStore: ProgressStore
    private var modelContainer: ModelContainer?
    private var autoShowTask: Task<Void, Never>?

    init(
        service: LLMServiceProtocol,
        progressStore: ProgressStore = .shared
    ) {
        self.service = service
        self.progressStore = progressStore
    }

    func bootstrap() async {
        modelState = .loading
        do {
            let container = try await service.loadModel()
            modelContainer = container
            modelState = .loaded
        } catch {
            modelState = .error(error.localizedDescription)
        }
    }

    /// Called by the view when the user advances past `OpeningView`.
    func transitionToFreePlay() {
        phase = .freePlay(playsSoFar: 0)
    }

    /// Called by the view after each user submit during free-play.
    /// Updates best-so-far, bumps the plays count. Does NOT
    /// auto-advance to challenge intro — the view decides based on
    /// its own logic (auto after delay, or via showChallengeManually).
    func recordPlay(top1Probability: Double) {
        bestSoFar = max(bestSoFar, top1Probability)
        let next = currentPlays + 1
        phase = .freePlay(playsSoFar: next)
    }

    /// User explicitly tapped the "我准备好了" chip. Cancels any
    /// pending auto-show task and jumps to challenge intro.
    func showChallengeManually() {
        autoShowTask?.cancel()
        autoShowTask = nil
        phase = .challengeIntro
    }

    /// User accepted the challenge. Writes persistence and invokes
    /// the closure passed by the App root.
    func acceptChallenge(onComplete: @escaping () -> Void) {
        autoShowTask?.cancel()
        autoShowTask = nil
        progressStore.hasSeenOnboarding = true
        onComplete()
    }

    /// Schedule the auto-show: after the 2nd play + a 3-second delay,
    /// jump to challenge intro unless the user already moved past it.
    func scheduleAutoShowIfSecondPlay() {
        guard currentPlays == 2 else { return }
        autoShowTask?.cancel()
        autoShowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if case .freePlay(let n) = self.phase, n >= 2 {
                self.phase = .challengeIntro
            }
        }
    }

    private var currentPlays: Int {
        if case .freePlay(let n) = phase { return n }
        return 0
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add llm-visualizer/Models/OnboardingState.swift \
        llm-visualizer/ViewModels/OnboardingViewModel.swift \
        llm-visualizerTests/OnboardingViewModelTests.swift
git commit -m "feat(Onboarding): OnboardingPhase + ViewModel (TDD)"
```

---

### Task 5: `LLMService.predictNextTokens` — protocol + mock

**Files:**
- Modify: `llm-visualizer/Services/LLMService.swift` (extend protocol + mock)
- Create: `llm-visualizerTests/LLMServicePredictTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/LLMServicePredictTests.swift`:

```swift
//
//  LLMServicePredictTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

@MainActor
struct LLMServicePredictTests {

    @Test func mockReturnsStubbedCandidates() async throws {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.32),
            TokenCandidate(id: 2, text: "不", probability: 0.18),
            TokenCandidate(id: 3, text: "的", probability: 0.14),
        ]
        let result = try await mock.predictNextTokens(prompt: "今天天气真", topK: 3)
        #expect(result.count == 3)
        #expect(result[0].text == "好")
        #expect(result[0].probability == 0.32)
    }

    @Test func mockDefaultsToEmptyWhenUnset() async throws {
        let mock = MockLLMService()
        let result = try await mock.predictNextTokens(prompt: "x", topK: 4)
        #expect(result.isEmpty)
    }

    @Test func mockTruncatesToTopK() async throws {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = (1...10).map { i in
            TokenCandidate(id: i, text: "t\(i)", probability: Double(11 - i) / 55.0)
        }
        let result = try await mock.predictNextTokens(prompt: "x", topK: 3)
        #expect(result.count == 3)
        #expect(result[0].text == "t1")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/LLMServicePredictTests
```

Expected: build fails, "Cannot find 'predictNextTokens' in scope".

- [ ] **Step 3: Extend `LLMServiceProtocol`**

In `llm-visualizer/Services/LLMService.swift`, modify the protocol declaration (around line 12). Replace the entire protocol block with:

```swift
protocol LLMServiceProtocol: Sendable {
    func loadModel() async throws -> ModelContainer
    func generate(
        messages: [Message],
        model: ModelContainer,
        onToken: @escaping @Sendable (Int) -> Void
    ) async throws -> AsyncStream<Generation>
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate]
}
```

- [ ] **Step 4: Extend `MockLLMService`**

In the same file, find `final class MockLLMService` (around line 131) and add the stubbed property + the new method. Insert these lines right after `var stubbedFinish: Bool = true` (around line 138):

```swift
    var stubbedPredictTopK: [TokenCandidate] = []
```

Then find `private func makeStubContainer()` (around line 181) and insert the new method right **before** it:

```swift
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate] {
        let clamped = max(0, topK)
        return Array(stubbedPredictTopK.prefix(clamped))
    }
```

- [ ] **Step 5: Stub the real implementation**

Add a placeholder real implementation so the protocol is fully satisfied and the project still compiles. Inside the real `LLMService` class, after the existing `generate(...)` method (around line 84), add:

```swift
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate] {
        // Full implementation lands in Task 6.
        return []
    }
```

- [ ] **Step 6: Run tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 3 tests pass.

- [ ] **Step 7: Commit**

```bash
git add llm-visualizer/Services/LLMService.swift \
        llm-visualizerTests/LLMServicePredictTests.swift
git commit -m "feat(Service): predictNextTokens protocol + mock (TDD stub)"
```

---

### Task 6: `LLMService.predictNextTokens` — real implementation

**Files:**
- Modify: `llm-visualizer/Services/LLMService.swift` (replace stub with real impl)
- Create: `llm-visualizerTests/LLMServicePredictIntegrationTests.swift`

- [ ] **Step 1: Discover the MLX API surface**

Read the mlx-swift-lm source for the model-forward + token-decode pattern. Quick path:

```bash
grep -rn "prepare(input:" /Users/africamonkey/Library/Developer/Xcode/DerivedData/llm-visualizer-*/SourcePackages/checkouts/mlx-swift-lm/Sources 2>/dev/null | head -10
```

Look for: `LanguageModel.callAsFunction` (or `_callAsFunction`) — the method that does a forward pass and returns `LMOutput` whose `.logits` is the logits tensor.

Also find how `context.processor.prepare(input: UserInput)` is called (we already use this in `generate`). The result has `.text` (the `LMInput.Text`) which is fed into the model.

- [ ] **Step 2: Write the integration test**

Create `llm-visualizerTests/LLMServicePredictIntegrationTests.swift`:

```swift
//
//  LLMServicePredictIntegrationTests.swift
//
//  These tests require the real model and a Metal-capable simulator
//  (or device). Skipped if XCTestConfigurationFilePath is set.

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct LLMServicePredictIntegrationTests {

    private func skipIfTestBundle() -> Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @Test func realPredictReturnsTopK() async throws {
        guard !skipIfTestBundle() else { return }
        let service = LLMService()
        let candidates = try await service.predictNextTokens(
            prompt: "今天天气真", topK: 4)
        #expect(candidates.count == 4)
        #expect(candidates[0].probability >= candidates[1].probability)
        // Sanity: probabilities sum is near 1.0 (after softmax).
        let sum = candidates.reduce(0.0) { $0 + $1.probability }
        #expect(sum > 0.0)
    }

    @Test func highlyPredictablePromptHitsHighTop1() async throws {
        guard !skipIfTestBundle() else { return }
        let service = LLMService()
        let candidates = try await service.predictNextTokens(
            prompt: "2 + 2 =", topK: 1)
        #expect(candidates.count == 1)
        // Loose expectation — model is small but should be very confident.
        #expect(candidates[0].probability > 0.5)
    }
}
```

Note: the `skipIfTestBundle` guard mirrors the existing pattern in `ChatView.swift`. Real-model tests are too slow for CI to run every build; they're there to be run manually on a Metal simulator/device.

- [ ] **Step 3: Run the integration test to verify it fails (or hangs)**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/LLMServicePredictIntegrationTests
```

Expected: stub returns `[]`, so `candidates.count == 4` fails. The `skipIfTestBundle` guard means in test bundle runs the test silently passes — to actually exercise it, run on a real simulator without the `XCTestConfigurationFilePath` env var.

- [ ] **Step 4: Implement the real `predictNextTokens`**

Replace the stub in `llm-visualizer/Services/LLMService.swift` (added in Task 5 Step 5) with the real implementation. The shape:

```swift
    func predictNextTokens(prompt: String, topK: Int) async throws -> [TokenCandidate] {
        let container = try await ensureContainer()
        return try await container.perform { context in
            let chatMessages = [Chat.Message(role: .user, content: prompt)]
            let userInput = UserInput(chat: chatMessages)
            let lmInput = try await context.processor.prepare(input: userInput)
            let logits = context.model(lmInput.text)
            // logits shape: [batch=1, seq, vocab]. Take last position.
            let lastLogits = logits[0, logits.dim(1) - 1, 0...].asType(.float32)
            let probs = softmax(lastLogits, axis: -1)
            let k = min(max(topK, 1), probs.dim(0))
            let (topValues, topIndices) = topk(probs, k, sorted: true)
            let tokenizer = context.tokenizer
            var out: [TokenCandidate] = []
            out.reserveCapacity(k)
            for i in 0..<k {
                let tokenId = Int(topIndices[i].item(Int32.self))
                let prob = Double(topValues[i].item(Float32.self))
                let text = tokenizer.decode(tokens: [tokenId], skipSpecialTokens: false)
                out.append(TokenCandidate(id: tokenId, text: text, probability: prob))
            }
            return out
        }
    }

    private func ensureContainer() async throws -> ModelContainer {
        if let cached { return cached }
        let container = try await loadModel()
        return container
    }
```

Implementation notes the executor may need to tune:

- The exact argument label on `softmax` (`axis:` vs unnamed second arg) and on `topk` (`k:` vs unnamed, `sorted:`) differs by mlx-swift version. If the compiler complains, drop the labels and rely on positional arguments. The tests verify the *output shape* not the exact API spelling.
- `topIndices[i].item(Int32.self)` — if the indices tensor is `Int64`, change to `Int64.self` and cast.
- If the project's pinned `mlx-swift-lm` version doesn't expose `logits` on `LMOutput`, fall back to using `context.model(lmInput.text, cache: nil, state: nil)` and reading `.logits` from the returned `LMOutput`. (The spec section §5.1 anticipates this — it's the same call path `generate()` uses internally; we just stop before sampling.)
- If `tokenizer.decode(tokens:skipSpecialTokens:)` is unavailable, use `tokenizer.decode([tokenId])`.

If the API truly isn't reachable (locked behind non-public types), stop and report — that's a spec-level risk surfaced by the implementation, not a failure to follow the plan.

- [ ] **Step 5: Build to confirm it compiles**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. If you hit API mismatches per the notes above, fix in place.

- [ ] **Step 6: Run the integration test on a Metal simulator**

Pick a Metal-capable simulator (most arm64 iOS Simulators are):

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/LLMServicePredictIntegrationTests
```

Expected: model loads, returns 4 candidates, top-1 ≥ top-2 ≥ … by probability.

- [ ] **Step 7: Re-run all tests (regression)**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: all tests pass (existing + new).

- [ ] **Step 8: Commit**

```bash
git add llm-visualizer/Services/LLMService.swift \
        llm-visualizerTests/LLMServicePredictIntegrationTests.swift
git commit -m "feat(Service): real predictNextTokens via single forward pass"
```

---

### Task 7: `Level1ViewModel`

**Files:**
- Create: `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Create: `llm-visualizerTests/Level1ViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/Level1ViewModelTests.swift`:

```swift
//
//  Level1ViewModelTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

private typealias Message = llm_visualizer.Message

@MainActor
struct Level1ViewModelTests {

    private func vm(stubbed: [TokenCandidate]) -> Level1ViewModel {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = stubbed
        return Level1ViewModel(service: mock)
    }

    @Test func initialState() {
        let v = vm(stubbed: [])
        #expect(v.prompt.isEmpty)
        #expect(v.topCandidates.isEmpty)
        #expect(v.bestSoFar == 0.0)
        #expect(v.submitCount == 0)
        #expect(v.state == .playing)
    }

    @Test func submitEmptyPromptIsNoOp() async {
        let v = vm(stubbed: [])
        v.prompt = "   "
        await v.submit()
        #expect(v.topCandidates.isEmpty)
        #expect(v.submitCount == 0)
    }

    @Test func submitUpdatesCandidatesAndBestSoFar() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "好", probability: 0.40),
            TokenCandidate(id: 2, text: "不", probability: 0.20),
        ])
        v.prompt = "今天天气真"
        await v.submit()
        #expect(v.topCandidates.count == 2)
        #expect(v.bestSoFar == 0.40)
        #expect(v.submitCount == 1)
    }

    @Test func bestSoFarIsMax() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.10),
            TokenCandidate(id: 2, text: "x", probability: 0.55),
            TokenCandidate(id: 3, text: "x", probability: 0.30),
        ])
        v.prompt = "a"; await v.submit()
        v.prompt = "b"; await v.submit()
        v.prompt = "c"; await v.submit()
        #expect(v.bestSoFar == 0.55)
    }

    @Test func top1Over90PercentPassesLevel() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "国", probability: 0.95),
        ])
        v.prompt = "中华人民共和"
        await v.submit()
        #expect(v.state == .passed)
    }

    @Test func passIsStickyAfterLowerSubmission() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "国", probability: 0.95),
            TokenCandidate(id: 2, text: "a", probability: 0.20),
        ])
        v.prompt = "x"; await v.submit()
        #expect(v.state == .passed)
        v.prompt = "y"; await v.submit()
        #expect(v.state == .passed)
    }

    @Test func belowThresholdStaysPlaying() async {
        let v = vm(stubbed: [
            TokenCandidate(id: 1, text: "x", probability: 0.30),
        ])
        v.prompt = "x"
        await v.submit()
        #expect(v.state == .playing)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:llm-visualizerTests/Level1ViewModelTests
```

Expected: build fails, "Cannot find 'Level1ViewModel' in scope".

- [ ] **Step 3: Implement `Level1ViewModel`**

Create `llm-visualizer/ViewModels/Level1ViewModel.swift`:

```swift
//
//  Level1ViewModel.swift
//

import Foundation
import MLXLMCommon
import os

@MainActor
@Observable
final class Level1ViewModel {

    enum State: Equatable { case playing, passed }

    static let passThreshold: Double = 0.90

    private let service: LLMServiceProtocol
    private var modelContainer: ModelContainer?
    private var autoClearTask: Task<Void, Never>?

    var prompt: String = ""
    var topCandidates: [TokenCandidate] = []
    var bestSoFar: Double = 0.0
    var submitCount: Int = 0
    var state: State = .playing
    var isLoading: Bool = false
    var errorBanner: String?

    init(service: LLMServiceProtocol) {
        self.service = service
    }

    func bootstrap() async {
        do {
            let container = try await service.loadModel()
            modelContainer = container
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func submit() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let container = try await ensureContainer()
            let candidates = try await service.predictNextTokens(
                prompt: trimmed, topK: 4)
            topCandidates = candidates
            submitCount += 1
            if let top1 = candidates.first {
                bestSoFar = max(bestSoFar, top1.probability)
                if top1.probability > Self.passThreshold, state != .passed {
                    state = .passed
                }
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func continueAfterPass() {
        // Celebration dismissed; state stays .passed so the ✓ badge
        // remains in the header and the goal indicator doesn't re-suggest.
    }

    private func ensureContainer() async throws -> ModelContainer {
        if let m = modelContainer { return m }
        let m = try await service.loadModel()
        modelContainer = m
        return m
    }

    private func showError(_ message: String) {
        errorBanner = message
        autoClearTask?.cancel()
        autoClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            if self.errorBanner == message { self.errorBanner = nil }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Re-run the same `xcodebuild test` command. Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/Level1ViewModel.swift \
        llm-visualizerTests/Level1ViewModelTests.swift
git commit -m "feat(Level1): Level1ViewModel (TDD)"
```

---

## Phase 2: UI Primitives (Tasks 8–13)

These tasks build reusable SwiftUI views. They have **no unit tests** — the visual decisions are captured in the brainstorming mockups, and verification is manual in the simulator (covered in Task 22). Each task produces one focused file.

### Task 8: `ProbabilityBarsView`

**Files:**
- Create: `llm-visualizer/Views/Level1/ProbabilityBarsView.swift`

Reference mockup: `.superpowers/brainstorm/18686-1782225140/content/probability-bars.html` (option B, selected).

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Level1/ProbabilityBarsView.swift`:

```swift
//
//  ProbabilityBarsView.swift
//

import SwiftUI

struct ProbabilityBarsView: View {

    let candidates: [TokenCandidate]
    var isPassed: Bool = false

    private var top1: TokenCandidate? { candidates.first }
    private var others: [TokenCandidate] { Array(candidates.dropFirst().prefix(3)) }

    private var passColor: Color { Color(red: 0.13, green: 0.77, blue: 0.37) } // #22c55e
    private var accent: Color { isPassed ? passColor : Color.accentColor }
    private var muted: Color { isPassed ? passColor.opacity(0.7) : Color.accentColor.opacity(0.65) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            top1Card
            if !others.isEmpty {
                Text(String(localized: "其他可能", defaultValue: "其他可能"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                VStack(spacing: 6) {
                    ForEach(others) { c in
                        row(for: c)
                    }
                }
            }
        }
    }

    private var top1Card: some View {
        VStack(spacing: 6) {
            Text(String(localized: "AI 最可能的下一词", defaultValue: "AI 最可能的下一词"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(top1?.text ?? "—")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(percentString(top1?.probability))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPassed ? passColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func row(for c: TokenCandidate) -> some View {
        HStack(spacing: 10) {
            Text(c.text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(muted)
                        .frame(width: geo.size.width * CGFloat(c.probability))
                }
            }
            .frame(height: 10)
            Text(percentString(c.probability))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemBackground))
        )
    }

    private func percentString(_ p: Double?) -> String {
        guard let p else { return "—" }
        return String(format: "%.0f%%", p * 100)
    }
}

#Preview {
    VStack {
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: "好", probability: 0.32),
            TokenCandidate(id: 2, text: "不", probability: 0.18),
            TokenCandidate(id: 3, text: "的", probability: 0.14),
            TokenCandidate(id: 4, text: "很", probability: 0.09),
        ])
        ProbabilityBarsView(candidates: [
            TokenCandidate(id: 1, text: "国", probability: 0.95),
        ], isPassed: true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. If the project has the synchronized folder enabled, the new file is picked up automatically. If not, drag the file into the project navigator.

- [ ] **Step 3: Manual preview check**

In Xcode, open the canvas for `ProbabilityBarsView.swift` and confirm:

- Top-1 card shows large token + percentage
- Three gray rows below (when there are 4 candidates)
- Pass variant (second preview) shows green border + green text
- Light and dark mode both look right (toggle via simulator)

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/Views/Level1/ProbabilityBarsView.swift
git commit -m "feat(Views): ProbabilityBarsView (Top-1 + Top-3)"
```

---

### Task 9: `InspirationButtonsView`

**Files:**
- Create: `llm-visualizer/Views/Common/InspirationButtonsView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Common/InspirationButtonsView.swift`:

```swift
//
//  InspirationButtonsView.swift
//

import SwiftUI

struct InspirationButtonsView: View {

    static let defaultFragments: [String] = [
        "我爱吃",
        "明天我要去",
        "人生最重要的是",
        "今天天气真",
        "太阳从东边",
        "2 + 2 =",
        "中国的首都是",
    ]

    let fragments: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(fragments, id: \.self) { f in
                    Button {
                        onTap(f)
                    } label: {
                        Text(f)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    InspirationButtonsView(
        fragments: InspirationButtonsView.defaultFragments,
        onTap: { _ in }
    )
    .padding()
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In the canvas: chips are horizontally scrollable, capsule-shaped, accent-colored, don't show a scroll indicator.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Common/InspirationButtonsView.swift
git commit -m "feat(Views): InspirationButtonsView"
```

---

### Task 10: `NarratorLineView`

**Files:**
- Create: `llm-visualizer/Views/Level1/NarratorLineView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Level1/NarratorLineView.swift`:

```swift
//
//  NarratorLineView.swift
//

import SwiftUI

struct NarratorLineView: View {

    enum Sentiment: Equatable {
        case high     // ≥ 0.70
        case medium   // 0.40 … 0.70
        case low      // < 0.40
        case passed   // top-1 over the pass threshold (post-pass only)

        var text: String {
            switch self {
            case .high:
                return String(localized: "这次 AI 挺确定的。", defaultValue: "这次 AI 挺确定的。")
            case .medium:
                return String(localized: "这次 AI 有点拿不准。", defaultValue: "这次 AI 有点拿不准。")
            case .low:
                return String(localized: "这次 AI 很犹豫，几个词分数差不多。",
                              defaultValue: "这次 AI 很犹豫，几个词分数差不多。")
            case .passed:
                return String(localized: "这次 AI 几乎闭眼都猜对了！",
                              defaultValue: "这次 AI 几乎闭眼都猜对了！")
            }
        }
    }

    let sentiment: Sentiment

    var body: some View {
        Text(sentiment.text)
            .font(.footnote.italic())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    static func sentiment(for top1Probability: Double) -> Sentiment {
        if top1Probability >= 0.70 { return .high }
        if top1Probability >= 0.40 { return .medium }
        return .low
    }
}

#Preview {
    VStack {
        NarratorLineView(sentiment: .high)
        NarratorLineView(sentiment: .medium)
        NarratorLineView(sentiment: .low)
        NarratorLineView(sentiment: .passed)
    }
    .padding()
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In canvas: four variants visible, italic, centered.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Level1/NarratorLineView.swift
git commit -m "feat(Views): NarratorLineView"
```

---

### Task 11: `ChallengeIntroCard`

**Files:**
- Create: `llm-visualizer/Views/Common/ChallengeIntroCard.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Common/ChallengeIntroCard.swift`:

```swift
//
//  ChallengeIntroCard.swift
//

import SwiftUI

struct ChallengeIntroCard: View {

    let bestSoFar: Double
    let onAccept: () -> Void

    private var goalText: String {
        let pct = Int((Level1ViewModel.passThreshold * 100).rounded())
        return String(
            localized: "目标：让 AI 对下一个词的预测超过 \(pct)%",
            defaultValue: "目标：让 AI 对下一个词的预测超过 \(pct)%"
        )
    }

    private var anchorText: String {
        let pct = Int((bestSoFar * 100).rounded())
        return String(
            localized: "你刚才最高才 \(pct)%，挑战一下",
            defaultValue: "你刚才最高才 \(pct)%，挑战一下"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "你可能发现了…", defaultValue: "你可能发现了…"))
                .font(.headline)
            Text(String(localized: "有时候 AI 很确定，有时候很犹豫。", defaultValue: "有时候 AI 很确定，有时候很犹豫。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(
                localized: "你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？",
                defaultValue: "你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？"
            ))
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                chip(text: goalText, accent: true)
                chip(text: anchorText, accent: false)
            }
            Button(action: onAccept) {
                Text(String(localized: "我准备好了", defaultValue: "我准备好了"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22).fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    private func chip(text: String, accent: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(accent ? Color.accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    accent ? Color.accentColor.opacity(0.10) : Color(.systemGray5)
                )
            )
    }
}

#Preview {
    ChallengeIntroCard(bestSoFar: 0.68, onAccept: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In canvas: card is centered, has title / body / two chips / one CTA. Change `bestSoFar: 0.68` to `bestSoFar: 0.42` in the preview to confirm the anchor chip updates.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Common/ChallengeIntroCard.swift
git commit -m "feat(Views): ChallengeIntroCard"
```

---

### Task 12: `PassCelebrationView`

**Files:**
- Create: `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`:

```swift
//
//  PassCelebrationView.swift
//

import SwiftUI

struct PassCelebrationView: View {

    let onContinue: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.accentColor.opacity(0.18), Color(.systemBackground)],
                center: .init(x: 0.5, y: 0.4),
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 80))
                Text("FIRST CLEAR")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Color.accentColor)
                Text(String(
                    localized: "你让 AI 闭眼都猜对了",
                    defaultValue: "你让 AI 闭眼都猜对了"
                ))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(String(
                    localized: "当上下文足够明确，模型其实早就知道下一个词是什么。",
                    defaultValue: "当上下文足够明确，模型其实早就知道下一个词是什么。"
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: onContinue) {
                    Text(String(localized: "再来一次", defaultValue: "再来一次"))
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                Text(String(localized: "下一关在路上", defaultValue: "下一关在路上"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

#Preview {
    PassCelebrationView(onContinue: {})
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In canvas: full-screen radial gradient, trophy, "FIRST CLEAR" small caps, big title, body sentence, "再来一次" capsule, footer hint. Light + dark mode both look right.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/LevelShell/PassCelebrationView.swift
git commit -m "feat(Views): PassCelebrationView"
```

---

### Task 13: `LevelHeaderView`

**Files:**
- Create: `llm-visualizer/Views/Common/LevelHeaderView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Common/LevelHeaderView.swift`:

```swift
//
//  LevelHeaderView.swift
//

import SwiftUI

struct LevelHeaderView: View {

    let levelNumber: Int
    let subtitle: String
    let goalDescription: String
    let bestSoFar: Double
    let isComplete: Bool

    private var titleText: String {
        String(localized: "第 \(levelNumber) 关", defaultValue: "第 \(levelNumber) 关")
    }

    private var goalText: String {
        let pct = Int((Level1ViewModel.passThreshold * 100).rounded())
        return String(
            localized: "目标：让 Top-1 概率超过 \(pct)%",
            defaultValue: "目标：让 Top-1 概率超过 \(pct)%"
        )
    }

    private var bestText: String {
        let pct = Int((bestSoFar * 100).rounded())
        return String(
            localized: "最高纪录：\(pct)%",
            defaultValue: "最高纪录：\(pct)%"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(titleText)
                    .font(.headline)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if isComplete {
                    Text("✓")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.13, green: 0.77, blue: 0.37))
                }
            }
            HStack(spacing: 8) {
                Text(goalText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(bestText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack(spacing: 16) {
        LevelHeaderView(
            levelNumber: 1,
            subtitle: "让 AI 闭眼都猜对",
            goalDescription: "目标：让 Top-1 概率超过 90%",
            bestSoFar: 0.32,
            isComplete: false
        )
        LevelHeaderView(
            levelNumber: 1,
            subtitle: "让 AI 闭眼都猜对",
            goalDescription: "目标：让 Top-1 概率超过 90%",
            bestSoFar: 0.95,
            isComplete: true
        )
    }
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In canvas: title + subtitle + optional ✓; second line shows goal + best record.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Common/LevelHeaderView.swift
git commit -m "feat(Views): LevelHeaderView"
```

---

## Phase 3: Onboarding Views (Tasks 14–17)

These tasks compose the UI primitives into the three onboarding screens + the orchestrator.

### Task 14: `OpeningView`

**Files:**
- Create: `llm-visualizer/Views/Onboarding/OpeningView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Onboarding/OpeningView.swift`:

```swift
//
//  OpeningView.swift
//

import SwiftUI

struct OpeningView: View {

    let candidates: [TokenCandidate]
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "你的输入", defaultValue: "你的输入"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("今天天气真")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )

            if isLoading {
                ProgressView()
                    .padding(.vertical, 40)
            } else {
                ProbabilityBarsView(candidates: candidates)
            }

            Text(String(
                localized: "它没在想，只是给每个词打分。",
                defaultValue: "它没在想，只是给每个词打分。"
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: onTap) {
                Text(String(
                    localized: "这是真的吗？我来试试",
                    defaultValue: "这是真的吗？我来试试"
                ))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    OpeningView(
        candidates: [
            TokenCandidate(id: 1, text: "好", probability: 0.32),
            TokenCandidate(id: 2, text: "不", probability: 0.18),
            TokenCandidate(id: 3, text: "的", probability: 0.14),
            TokenCandidate(id: 4, text: "很", probability: 0.09),
        ],
        isLoading: false,
        onTap: {}
    )
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In canvas: input box at top, probability bars in middle, italic line "它没在想，只是给每个词打分。" + CTA capsule at bottom.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Onboarding/OpeningView.swift
git commit -m "feat(Views): OpeningView (pre-canned example)"
```

---

### Task 15: `FreePlayView`

**Files:**
- Create: `llm-visualizer/Views/Onboarding/FreePlayView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Onboarding/FreePlayView.swift`:

```swift
//
//  FreePlayView.swift
//

import SwiftUI

struct FreePlayView: View {

    @Bindable var viewModel: Level1ViewModel
    let playsSoFar: Int
    let onUserSubmitted: () -> Void
    let onTapReady: () -> Void

    private let fragments = InspirationButtonsView.defaultFragments

    private var showNarrator: Bool { playsSoFar >= 2 }
    private var narrator: NarratorLineView.Sentiment {
        NarratorLineView.sentiment(for: viewModel.topCandidates.first?.probability ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            inputSection
            ProbabilityBarsView(candidates: viewModel.topCandidates)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            if showNarrator {
                NarratorLineView(sentiment: narrator)
                    .padding(.bottom, 4)
            }
            Spacer(minLength: 8)
            footer
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(
                    localized: "换一句话试试，看 AI 怎么猜",
                    defaultValue: "换一句话试试，看 AI 怎么猜"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Spacer()
                if showNarrator {
                    Button(action: onTapReady) {
                        Text(String(
                            localized: "我准备好了",
                            defaultValue: "我准备好了"
                        ))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                TextField(
                    String(localized: "输入你的句子…", defaultValue: "输入你的句子…"),
                    text: $viewModel.prompt
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                )
                Button {
                    Task {
                        await viewModel.submit()
                        if !viewModel.topCandidates.isEmpty { onUserSubmitted() }
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            InspirationButtonsView(fragments: fragments) { fragment in
                viewModel.prompt = fragment
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var footer: some View {
        HStack {
            Text(String(
                localized: "已玩 \(playsSoFar) 次",
                defaultValue: "已玩 \(playsSoFar) 次"
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
            Spacer()
            Text(String(
                localized: "最高纪录 \(Int((viewModel.bestSoFar * 100).rounded()))%",
                defaultValue: "最高纪录 \(Int((viewModel.bestSoFar * 100).rounded()))%"
            ))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

`FreePlayView` has no `#Preview` because it depends on `@Bindable Level1ViewModel`. To preview it, add this temporarily (delete before commit):

```swift
#Preview {
    let mock = MockLLMService()
    mock.stubbedPredictTopK = [
        TokenCandidate(id: 1, text: "好", probability: 0.32),
        TokenCandidate(id: 2, text: "不", probability: 0.18),
        TokenCandidate(id: 3, text: "的", probability: 0.14),
        TokenCandidate(id: 4, text: "很", probability: 0.09),
    ]
    let vm = Level1ViewModel(service: mock)
    return FreePlayView(viewModel: vm, playsSoFar: 2, onUserSubmitted: {}, onTapReady: {})
}
```

In canvas: input row + chips + bars + narrator (since `playsSoFar: 2`) + footer with count and best.

Delete the `#Preview` block before committing — it's a courtesy preview, not a committed artifact.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Onboarding/FreePlayView.swift
git commit -m "feat(Views): FreePlayView"
```

---

### Task 16: `ChallengeIntroView`

**Files:**
- Create: `llm-visualizer/Views/Onboarding/ChallengeIntroView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Onboarding/ChallengeIntroView.swift`:

```swift
//
//  ChallengeIntroView.swift
//

import SwiftUI

struct ChallengeIntroView: View {

    let bestSoFar: Double
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack {
                Spacer()
                ChallengeIntroCard(bestSoFar: bestSoFar, onAccept: onAccept)
                Spacer()
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    ChallengeIntroView(bestSoFar: 0.68, onAccept: {})
}
```

- [ ] **Step 2: Build + manual preview check**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

In canvas: dimmed backdrop, card centered.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Onboarding/ChallengeIntroView.swift
git commit -m "feat(Views): ChallengeIntroView"
```

---

### Task 17: `OnboardingFlowView`

**Files:**
- Create: `llm-visualizer/Views/Onboarding/OnboardingFlowView.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Onboarding/OnboardingFlowView.swift`:

```swift
//
//  OnboardingFlowView.swift
//

import SwiftUI

struct OnboardingFlowView: View {

    @State var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    private let openingPrompt = "今天天气真"

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .opening:
                openingScreen
            case .freePlay:
                FreePlayView(
                    viewModel: makeLevel1VM(),
                    playsSoFar: currentPlays,
                    onUserSubmitted: handleSubmit,
                    onTapReady: { viewModel.showChallengeManually() }
                )
            case .challengeIntro:
                FreePlayView(
                    viewModel: makeLevel1VM(),
                    playsSoFar: currentPlays,
                    onUserSubmitted: handleSubmit,
                    onTapReady: { viewModel.showChallengeManually() }
                )
                .allowsHitTesting(false)
                ChallengeIntroView(
                    bestSoFar: viewModel.bestSoFar,
                    onAccept: { viewModel.acceptChallenge(onComplete: onComplete) }
                )
            }
        }
        .task {
            await viewModel.bootstrap()
            // Pre-load the opening example.
            do {
                let container = try await LLMService().loadModel()
                let candidates = try await LLMService().predictNextTokens(
                    prompt: openingPrompt, topK: 4)
                _ = container
                openingCandidates = candidates
            } catch {
                openingCandidates = []
            }
        }
    }

    // MARK: - Opening screen

    @State private var openingCandidates: [TokenCandidate] = []
    @State private var openingLoading: Bool = true

    private var openingScreen: some View {
        OpeningView(
            candidates: openingCandidates,
            isLoading: openingLoading,
            onTap: { viewModel.transitionToFreePlay() }
        )
    }

    // MARK: - Free-play helpers

    private var currentPlays: Int {
        if case .freePlay(let n) = viewModel.phase { return n }
        return 0
    }

    @State private var freePlayVM: Level1ViewModel?

    private func makeLevel1VM() -> Level1ViewModel {
        if let freePlayVM { return freePlayVM }
        let vm = Level1ViewModel(service: LLMService())
        freePlayVM = vm
        return vm
    }

    private func handleSubmit() {
        guard let top1 = freePlayVM?.topCandidates.first else { return }
        viewModel.recordPlay(top1Probability: top1.probability)
        viewModel.scheduleAutoShowIfSecondPlay()
    }
}
```

Notes:
- The free-play VM is built lazily and shared across phase transitions so
  the bars state persists when the challenge intro overlay appears.
- `ChallengeIntroView` overlay dims + greys-out the underlying free-play.
  We disable hits with `.allowsHitTesting(false)` so the user can only
  interact with the card.

- [ ] **Step 2: Build**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. If you hit compilation issues around `LLMService().loadModel()` / `LLMService().predictNextTokens(...)` being called twice (one for container caching, one for the call), consolidate to one path — fetch container once, then call. The simpler form:

```swift
.task {
    await viewModel.bootstrap()
    let service = LLMService()
    do {
        let container = try await service.loadModel()
        let candidates = try await container.perform { context in
            // ... mirror real impl using LLMService internals is too leaky
            // Instead, expose a convenience helper:
        }
        openingCandidates = candidates
    } catch {
        openingCandidates = []
    }
}
```

If the leak-through is awkward, fall back to a single helper:

```swift
extension LLMServiceProtocol {
    func predict(_ prompt: String, topK: Int) async throws -> [TokenCandidate] {
        try await predictNextTokens(prompt: prompt, topK: topK)
    }
}
```

…and call `service.predict(openingPrompt, topK: 4)` directly. The `predictNextTokens` method already handles model loading internally via `ensureContainer`. Simplify `.task` to:

```swift
.task {
    await viewModel.bootstrap()
    let service = LLMService()
    do {
        openingCandidates = try await service.predictNextTokens(prompt: openingPrompt, topK: 4)
    } catch {
        openingCandidates = []
    }
    openingLoading = false
}
```

If you make any code changes here to clean up the `.task`, mention them in the commit body.

- [ ] **Step 3: Manual smoke test in simulator**

In Xcode, set the deployment target, build & run on iPhone 17 simulator. Walk through the 3 phases manually:

- App opens to OpeningView with "今天天气真" + 4 bars
- Tap "这是真的吗？我来试试" → FreePlayView
- Type a sentence, tap submit → bars update
- Repeat once → narrator appears + "我准备好了" chip in header
- Tap "我准备好了" (or wait 3s) → challenge intro overlay
- Tap "我准备好了" CTA → `onComplete` fires (verify via a print or by adding a temporary label)

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/Views/Onboarding/OnboardingFlowView.swift
git commit -m "feat(Views): OnboardingFlowView orchestrator"
```

---

## Phase 4: Level 1 + Integration (Tasks 18–21)

### Task 18: `Level1View`

**Files:**
- Create: `llm-visualizer/Views/Level1/Level1View.swift`

- [ ] **Step 1: Implement the view**

Create `llm-visualizer/Views/Level1/Level1View.swift`:

```swift
//
//  Level1View.swift
//

import SwiftUI

struct Level1View: View {

    @Bindable var viewModel: Level1ViewModel
    let session: Level1Session
    let showNarrator: Bool

    private let fragments = InspirationButtonsView.defaultFragments

    var body: some View {
        VStack(spacing: 0) {
            inputSection
            ProbabilityBarsView(
                candidates: viewModel.topCandidates,
                isPassed: viewModel.state == .passed
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            if showNarrator {
                NarratorLineView(
                    sentiment: viewModel.state == .passed
                        ? .passed
                        : NarratorLineView.sentiment(
                            for: viewModel.topCandidates.first?.probability ?? 0
                        )
                )
                .padding(.bottom, 4)
            }
            Spacer(minLength: 8)
            footer
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .passed {
                session.evaluate()
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "你的输入", defaultValue: "你的输入"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(
                    String(localized: "输入你的句子…", defaultValue: "输入你的句子…"),
                    text: $viewModel.prompt
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                )
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(
                    viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isLoading
                )
            }
            InspirationButtonsView(fragments: fragments) { fragment in
                viewModel.prompt = fragment
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var footer: some View {
        HStack {
            Text(String(
                localized: "已提交 \(viewModel.submitCount) 次",
                defaultValue: "已提交 \(viewModel.submitCount) 次"
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
            Spacer()
            Text(String(
                localized: "最高纪录 \(Int((viewModel.bestSoFar * 100).rounded()))%",
                defaultValue: "最高纪录 \(Int((viewModel.bestSoFar * 100).rounded()))%"
            ))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. (It will reference `Level1Session` which doesn't exist yet — that's Task 19.)

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Level1/Level1View.swift
git commit -m "feat(Views): Level1View"
```

---

### Task 19: `Level1Session` + register in `LevelRegistry`

**Files:**
- Create: `llm-visualizer/Models/Level1Session.swift`
- Modify: `llm-visualizer/Models/Levels.swift` (uncomment the registry entry)

- [ ] **Step 1: Implement `Level1Session`**

Create `llm-visualizer/Models/Level1Session.swift`:

```swift
//
//  Level1Session.swift
//

import SwiftUI

@MainActor
final class Level1Session: LevelSession {

    let viewModel: Level1ViewModel

    init(viewModel: Level1ViewModel = Level1ViewModel(service: LLMService())) {
        self.viewModel = viewModel
        super.init(
            id: 1,
            title: String(localized: "第 1 关", defaultValue: "第 1 关"),
            subtitle: String(
                localized: "让 AI 闭眼都猜对",
                defaultValue: "让 AI 闭眼都猜对"
            ),
            goalDescription: String(
                localized: "让 Top-1 概率超过 90%",
                defaultValue: "让 Top-1 概率超过 90%"
            )
        )
    }

    override func makeContentView() -> AnyView {
        AnyView(
            Level1View(
                viewModel: viewModel,
                session: self,
                showNarrator: true
            )
        )
    }

    override func evaluate() {
        if viewModel.state == .passed, !isComplete {
            isComplete = true
        }
    }

    func bootstrap() async {
        await viewModel.bootstrap()
    }
}
```

- [ ] **Step 2: Register in `LevelRegistry`**

In `llm-visualizer/Models/Levels.swift`, replace the empty registry array:

```swift
enum LevelRegistry {
    static let all: [LevelSession.Type] = [
        Level1Session.self
    ]
}
```

- [ ] **Step 3: Build + run regression tests**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: all tests still pass (no new tests in this task, just verifying nothing broke).

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/Models/Level1Session.swift \
        llm-visualizer/Models/Levels.swift
git commit -m "feat(Level1): Level1Session + register in LevelRegistry"
```

---

### Task 20: `LevelShellView` + `AppRootView` + app entry

**Files:**
- Create: `llm-visualizer/Views/LevelShell/LevelShellView.swift`
- Create: `llm-visualizer/AppRootView.swift`
- Modify: `llm-visualizer/llm_visualizerApp.swift`

- [ ] **Step 1: Implement `LevelShellView`**

Create `llm-visualizer/Views/LevelShell/LevelShellView.swift`:

```swift
//
//  LevelShellView.swift
//

import SwiftUI

struct LevelShellView: View {

    @State var currentSession: LevelSession

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LevelHeaderView(
                    levelNumber: currentSession.id,
                    subtitle: currentSession.subtitle,
                    goalDescription: currentSession.goalDescription,
                    bestSoFar: bestSoFar,
                    isComplete: currentSession.isComplete
                )
                Divider()
                currentSession.makeContentView()
            }

            if let level1 = currentSession as? Level1Session,
               level1.viewModel.state == .passed,
               !dismissed {
                PassCelebrationView(
                    onContinue: { withAnimation { dismissed = true } }
                )
            }
        }
        .task {
            if let level1 = currentSession as? Level1Session {
                await level1.bootstrap()
            }
        }
    }

    @State private var dismissed: Bool = false

    private var bestSoFar: Double {
        (currentSession as? Level1Session)?.viewModel.bestSoFar ?? 0.0
    }
}
```

- [ ] **Step 2: Implement `AppRootView`**

Create `llm-visualizer/AppRootView.swift`:

```swift
//
//  AppRootView.swift
//

import SwiftUI

struct AppRootView: View {

    @State private var showOnboarding: Bool

    init() {
        _showOnboarding = State(initialValue: !ProgressStore.shared.hasSeenOnboarding)
    }

    var body: some View {
        if showOnboarding {
            OnboardingFlowView(
                viewModel: OnboardingViewModel(service: LLMService()),
                onComplete: { showOnboarding = false }
            )
        } else {
            LevelShellView(currentSession: Level1Session())
        }
    }
}
```

- [ ] **Step 3: Replace `ChatView` in `llm_visualizerApp.swift`**

Open `llm-visualizer/llm_visualizerApp.swift`. Replace the entire file body (after `import SwiftUI`) with:

```swift
@main
struct llm_visualizerApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
```

Save.

- [ ] **Step 4: Build**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`. If the project's synchronized-folder setup picks up the new files automatically, no project edits are needed. If not, drag the new view files into the project navigator manually.

- [ ] **Step 5: Smoke test in simulator**

Build & run on iPhone 17 simulator. Walk through:

- First launch → OnboardingFlowView (3 phases)
- Accept challenge → LevelShellView with Level 1
- Submit `2 + 2 =` → bars update, top-1 should be near 100%, pass celebration overlay appears
- Tap "再来一次" → overlay dismissed, ✓ badge in header
- Submit another prompt → bars update, overlay does NOT re-show
- Force-quit + relaunch → straight to Level 1 with ✓ badge (since `ProgressStore.hasSeenOnboarding == true` and `Level1Session.isComplete == true`)

- [ ] **Step 6: Commit**

```bash
git add llm-visualizer/Views/LevelShell/LevelShellView.swift \
        llm-visualizer/AppRootView.swift \
        llm-visualizer/llm_visualizerApp.swift
git commit -m "feat(App): AppRootView + LevelShellView (ChatView replaced)"
```

---

### Task 21: Localization (Localizable.xcstrings)

**Files:**
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Read the existing catalog**

Open `llm-visualizer/Resources/Localizable.xcstrings`. Note its top-level shape: `sourceLanguage`, `strings`, `version`. Each entry has `localizations.en.stringUnit.value` and `localizations.zh-Hans.stringUnit.value`.

- [ ] **Step 2: Add L1 strings**

Open the file in a text editor. The file is JSON, so insert each new key into the `strings` object. Order does not matter. For each key, add an entry like:

```json
"第 1 关" : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "第 1 关" } },
    "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "第 1 关" } }
  }
},
```

Keys to add (English and zh-Hans values are identical for these Chinese strings; that's fine — the source language is en and the catalog records what each locale actually shows):

| Key | en value | zh-Hans value |
|---|---|---|
| `第 1 关` | `第 1 关` | `第 1 关` |
| `让 AI 闭眼都猜对` | `让 AI 闭眼都猜对` | `让 AI 闭眼都猜对` |
| `目标：让 Top-1 概率超过 %@%%` | `目标：让 Top-1 概率超过 %@%%` | `目标：让 Top-1 概率超过 %@%%` |
| `最高纪录：%@%%` | `最高纪录：%@%%` | `最高纪录：%@%%` |
| `你的输入` | `你的输入` | `你的输入` |
| `AI 最可能的下一词` | `AI 最可能的下一词` | `AI 最可能的下一词` |
| `其他可能` | `其他可能` | `其他可能` |
| `这次 AI 挺确定的。` | `这次 AI 挺确定的。` | `这次 AI 挺确定的。` |
| `这次 AI 有点拿不准。` | `这次 AI 有点拿不准。` | `这次 AI 有点拿不准。` |
| `这次 AI 很犹豫，几个词分数差不多。` | `这次 AI 很犹豫，几个词分数差不多。` | `这次 AI 很犹豫，几个词分数差不多。` |
| `这次 AI 几乎闭眼都猜对了！` | `这次 AI 几乎闭眼都猜对了！` | `这次 AI 几乎闭眼都猜对了！` |
| `换一句话试试，看 AI 怎么猜` | `换一句话试试，看 AI 怎么猜` | `换一句话试试，看 AI 怎么猜` |
| `这是真的吗？我来试试` | `这是真的吗？我来试试` | `这是真的吗？我来试试` |
| `它没在想，只是给每个词打分。` | `它没在想，只是给每个词打分。` | `它没在想，只是给每个词打分。` |
| `你可能发现了…` | `你可能发现了…` | `你可能发现了…` |
| `有时候 AI 很确定，有时候很犹豫。` | `有时候 AI 很确定，有时候很犹豫。` | `有时候 AI 很确定，有时候很犹豫。` |
| `你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？` | `你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？` | `你能找到一句话，让 AI 确定到几乎闭着眼睛都能猜对吗？` |
| `我准备好了` | `我准备好了` | `我准备好了` |
| `你让 AI 闭眼都猜对了` | `你让 AI 闭眼都猜对了` | `你让 AI 闭眼都猜对了` |
| `当上下文足够明确，模型其实早就知道下一个词是什么。` | `当上下文足够明确，模型其实早就知道下一个词是什么。` | `当上下文足够明确，模型其实早就知道下一个词是什么。` |
| `再来一次` | `再来一次` | `再来一次` |
| `下一关在路上` | `下一关在路上` | `下一关在路上` |
| `FIRST CLEAR` | `FIRST CLEAR` | `FIRST CLEAR` |
| `已玩 %lld 次` | `已玩 %lld 次` | `已玩 %lld 次` |
| `已提交 %lld 次` | `已提交 %lld 次` | `已提交 %lld 次` |
| `最高纪录 %d%%` | `最高纪录 %d%%` | `最高纪录 %d%%` |
| `输入你的句子…` | `输入你的句子…` | `输入你的句子…` |
| `目标：让 AI 对下一个词的预测超过 %d%%` | `目标：让 AI 对下一个词的预测超过 %d%%` | `目标：让 AI 对下一个词的预测超过 %d%%` |
| `你刚才最高才 %d%%，挑战一下` | `你刚才最高才 %d%%，挑战一下` | `你刚才最高才 %d%%，挑战一下` |

- [ ] **Step 3: Validate JSON**

```bash
plutil -lint llm-visualizer/Resources/Localizable.xcstrings
```

Expected: `OK`. If it fails, the JSON is malformed — most likely a missing comma between entries.

- [ ] **Step 4: Verify Xcode recognizes the new keys**

Open Xcode, select the `.xcstrings` file, switch to the **Localizable** view in the right panel. Confirm 28 new entries appear (plus the 8 existing). If any show "New" or "Untranslated", fix them.

- [ ] **Step 5: Locale-switch smoke test**

In iOS Simulator: Settings → General → Language & Region → iPhone Language → 简体中文. Relaunch the app.

Expected: all L1 strings render in Chinese.

Switch back to English, relaunch — strings render in English (or unchanged since the values are identical, but the catalog lookup succeeds).

- [ ] **Step 6: Commit**

```bash
git add llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Resources): L1 strings (zh-Hans + en)"
```

---

## Phase 5: Verification (Task 22)

### Task 22: Manual end-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Cold-start, first-time user**

Force-quit the simulator (⇧⌘H twice → swipe up). Re-launch the app.

Expected:

- OnboardingFlowView shows OpeningView with "今天天气真" + 4 bars.
- Tapping "这是真的吗？我来试试" advances to FreePlayView.
- Typing a sentence and submitting updates bars.
- After 2 submits: narrator appears + "我准备好了" chip in header.
- Tapping the chip (or waiting 3s) shows challenge intro overlay.
- Tapping "我准备好了" in the overlay swaps to LevelShellView with Level 1.

- [ ] **Step 2: Level 1 pass**

In Level 1, type `2 + 2 =` and submit.

Expected:

- Top-1 token shows `4` (or whatever Qwen3 thinks), probability near or above 90%.
- ProbabilityBarsView recolors the Top-1 card border to green.
- PassCelebrationView appears as a full-screen overlay with 🏆, title, body, "再来一次" button.
- ✓ badge appears in LevelHeaderView.

- [ ] **Step 3: Continue playing**

Tap "再来一次" → overlay dismisses. Type a low-confidence prompt like `我爱吃` and submit.

Expected:

- Top-1 probability is much lower (10–20%).
- PassCelebrationView does NOT re-show (state stays `.passed`).
- Best record stays at the high value from Step 2.

- [ ] **Step 4: Restart persistence**

Force-quit and relaunch the app.

Expected:

- Onboarding is skipped (already seen).
- Level 1 immediately visible.
- ✓ badge in header (level complete).
- `bestSoFar` from Step 2 is restored.

Note: `bestSoFar` is in-memory state on `Level1ViewModel`. After restart it starts at 0 because the model is freshly created. If you want it persisted, that's a future task. The `isComplete` ✓ badge IS persisted via `ProgressStore`.

- [ ] **Step 5: Localization switch**

Set simulator to 简体中文 → relaunch.

Expected:

- All L1 strings render in Chinese.
- "FIRST CLEAR" stays English (intentional — it's stylized text).
- The numeric percent values still format correctly.

- [ ] **Step 6: Run the full unit-test suite one more time**

```bash
xcodebuild test -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: all tests pass.

- [ ] **Step 7: Tag the release**

```bash
git tag -a v0.2-onboarding-level1 -m "Onboarding flow + Level 1"
```

(Only if the user has asked for a tag.)

---

## Self-Review Checklist

Before considering the plan complete, verify the following:

- [ ] **Spec coverage:** walk through each spec section, confirm a task implements it:
  - §5.1 `predictNextTokens` → Task 6
  - §5.2 `LevelSession` + `LevelRegistry` → Tasks 3 + 19
  - §5.3 `ProgressStore` → Task 2
  - §5.4 `OnboardingPhase` + `OnboardingViewModel` → Task 4
  - §5.5 `Level1ViewModel` → Task 7
  - §5.6 `Level1View` → Task 18
  - §5.6 `ProbabilityBarsView` → Task 8
  - §5.6 `NarratorLineView` → Task 10
  - §5.6 `InspirationButtonsView` → Task 9
  - §5.6 `ChallengeIntroCard` → Task 11
  - §5.6 `PassCelebrationView` → Task 12
  - §5.6 `LevelHeaderView` → Task 13
  - §5.6 `OpeningView` → Task 14
  - §5.6 `FreePlayView` → Task 15
  - §5.6 `ChallengeIntroView` → Task 16
  - §5.6 `OnboardingFlowView` → Task 17
  - §5.6 `LevelShellView` → Task 20
  - §6.1 App launch / `AppRootView` → Task 20
  - §6.2 Onboarding flow data flow → Task 17
  - §6.3 Level 1 play data flow → Tasks 18 + 19
  - §6.4 `predictNextTokens` call sequence → Task 6
  - §7 UI design (mockups) → Tasks 8 (bars) + 14 (opening) + 15 (free play) + 16 (challenge intro) + 12 (pass)
  - §8 state interactions → covered by all integration
  - §9 localization → Task 21
  - §10 error handling → Task 7 (banner with auto-clear)
  - §11 unit tests → Tasks 1, 2, 3, 4, 5, 7
  - §11 manual verification → Task 22

- [ ] **TDD discipline:** Tasks 1–7 wrote failing tests first. UI tasks 8–22 are verification-by-canvas (per spec §11 "visual components verified manually").

- [ ] **No placeholders:** every code step has the actual code, every test step has the actual test, every build command is the full command.

- [ ] **Type consistency:** `LevelSession.evaluate()`, `Level1ViewModel.submit()`, `Level1ViewModel.state`, `Level1Session.bootstrap()`, `ProgressStore.shared`, `LLMService.predictNextTokens(prompt:topK:)` — same names across all tasks.

- [ ] **Frequent commits:** each task ends with a `git commit`. ~22 commits total.

- [ ] **No pbxproj edits expected** — synchronized folder should pick up new files. If Xcode complains at build time, drag the file into the project navigator manually.
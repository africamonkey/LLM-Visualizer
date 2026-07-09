# Level 1 UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 19 issues identified in the PM review of Level 1 (data persistence, empty promises, UI duplication, accessibility, error UX, dead code, P3 niceties). All work happens on branch `fix/level1-ux-polish` in `.worktrees/level1-fixes`.

**Architecture:** TDD for data layer (ProgressStore persistence, error mapping, probability-bar width, narrator sentiment, service contract). SwiftUI changes are made directly and verified by re-running the full unit-test target. Localization keys are added to `Localizable.xcstrings` and `extractFromLocalizedString` tools will pick them up on the next build.

**Tech Stack:** Swift 5.9+, SwiftUI (`@Observable`, `@Bindable`, `.transition`, `.accessibilityLabel`), Swift Testing (`@Test`, `#expect`), `Localizable.xcstrings` String Catalog.

**Reference:**
- PM review (the "spec"): see this conversation's earlier message
- Existing patterns: `llm-visualizer/Models/LevelProgress.swift`, `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Existing test patterns: `llm-visualizerTests/LevelProgressTests.swift`, `llm-visualizerTests/Level1ViewModelTests.swift`

**Test invocation convention** (derived data is shared with the main checkout to skip MLX package re-resolution):
```bash
DD=~/Library/Developer/Xcode/DerivedData/llm-visualizer-eppqmoleaocfdfgffvckcujzdqbd
xcodebuild test-without-building -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=9B6D70A2-34DC-4E1E-B8FE-9058FCE77307' \
  -derivedDataPath "$DD" \
  -only-testing:llm-visualizerTests/<TestClassName>
```

If `test-without-building` fails with "no such test target", re-run a `build-for-testing` first:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=9B6D70A2-34DC-4E1E-B8FE-9058FCE77307' \
  -derivedDataPath "$DD" build-for-testing
```

---

## File Structure

**New files:**
- `llm-visualizer/Models/Level2Session.swift` — placeholder Level 2 (stub content)
- `llm-visualizer/Models/LevelError.swift` — human-readable error mapping
- `llm-visualizer/Views/Level2/Level2View.swift` — "Coming soon" placeholder view
- `llm-visualizer/Views/Settings/SettingsView.swift` — settings sheet (replay + reset)
- `llm-visualizer/Views/Common/EmptyStateView.swift` — initial-empty guidance card
- `llm-visualizerTests/Level2RegistryTests.swift` — registry contains L1 + L2 stub
- `llm-visualizerTests/LevelErrorTests.swift` — error humanization
- `llm-visualizerTests/ProgressStoreResetTests.swift` — reset clears everything
- `README.md` — project overview

**Modified files:**
- `llm-visualizer/Models/LevelProgress.swift` — add `bestProbability` / `reset()`
- `llm-visualizer/Models/Level1Session.swift` — wire persisted best into view-model init
- `llm-visualizer/Models/Levels.swift` — register Level2Session
- `llm-visualizer/ViewModels/Level1ViewModel.swift` — load best on init, write best on submit, drop `continueAfterPass`, catch humanized errors
- `llm-visualizer/ViewModels/AppShellViewModel.swift` — also reset path (delete `hasSeenOnboarding` and `completedLevels`)
- `llm-visualizer/Services/LLMService.swift` — drop duplicate `Level1ViewModel` model container cache (P3-2)
- `llm-visualizer/Views/Level1/Level1View.swift` — drop duplicate best-record footer, add spinner, add empty state, add prompt length limit
- `llm-visualizer/Views/Level1/ProbabilityBarsView.swift` — min width, semantic fonts, accessibility labels, 0% handling
- `llm-visualizer/Views/Level1/NarratorLineView.swift` — accept new "passed + current sentiment" mode, new copy
- `llm-visualizer/Views/LevelShell/LevelShellView.swift` — settings entry point, echo prompt on celebration
- `llm-visualizer/Views/LevelShell/PassCelebrationView.swift` — echo user prompt, spring transition, drop "Next level" copy
- `llm-visualizer/Views/Common/InspirationButtonsView.swift` — bilingual fragments, append-not-replace
- `llm-visualizer/Views/Common/LevelHeaderView.swift` — settings button
- `llm-visualizer/Resources/Localizable.xcstrings` — new keys, drop symbol-only entries

**Deleted:**
- `llm-visualizer/ViewModels/Level1ViewModel.swift::continueAfterPass` (lines 67-70)
- The "·" "✓" "🏆" entries in `Localizable.xcstrings` (not localizable symbols)
- The duplicate best-record footer in `Level1View.swift`

---

## Task ordering

Tasks are designed to be runnable in order; some are independent and can be parallelized by a dispatcher. The recommended order:

1. T0: ProgressStore best-record persistence (P0.1) — TDD, foundation for P1.5
2. T1: Drop `continueAfterPass` dead code (P0.2)
3. T2: Level 2 stub (P0.3) — TDD for registry
4. T3: Inspiration fragments bilingual (P0.4)
5. T4: Drop footer duplicate + restore best from persistence (P1.5)
6. T5: Submit button spinner (P1.6)
7. T6: Narrator follows current top1 in passed state (P1.7) — TDD
8. T7: Initial empty state (P1.8)
9. T8: Inspiration appends, not replaces (P1.9)
10. T9: Probability bar min width + 0% (P1.10) — TDD
11. T10: Number format + plural fix (P1.11) — TDD
12. T11: Dynamic Type + accessibility (P2.12)
13. T12: Localization cleanup (P2.13)
14. T13: Error humanization (P2.14) — TDD
15. T14: Input length limit (P2.15)
16. T15: Celebration spring + echo prompt (P2.16 + P2.17)
17. T16: Settings sheet — replay onboarding + reset progress (P3-3 + P3-4) — TDD
18. T17: LLMService dedupe container cache (P3-2) — TDD
19. T18: README (P3-1)
20. T19: Final full-suite verification + PR

---

## Task 0: Persist `bestSoFar` in ProgressStore (P0.1)

**Files:**
- Modify: `llm-visualizer/Models/LevelProgress.swift`
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift:21-32`
- Test: `llm-visualizerTests/LevelProgressTests.swift` (extend)

- [ ] **Step 1: Write failing tests in `LevelProgressTests.swift`**

Add to the existing struct (right after `multipleLevelsAreIndependent`):
```swift
@Test func bestProbabilityDefaultsZero() {
    let store = ProgressStore(defaults: makeDefaults())
    #expect(store.bestProbability(1) == 0.0)
}

@Test func bestProbabilityRoundTrip() {
    let store = ProgressStore(defaults: makeDefaults())
    store.setBestProbability(1, 0.42)
    #expect(store.bestProbability(1) == 0.42)
}

@Test func bestProbabilityIsMonotonic() {
    let store = ProgressStore(defaults: makeDefaults())
    store.setBestProbability(1, 0.30)
    store.setBestProbability(1, 0.50)
    store.setBestProbability(1, 0.40)  // should not regress
    #expect(store.bestProbability(1) == 0.50)
}

@Test func bestProbabilityIsIndependentPerLevel() {
    let store = ProgressStore(defaults: makeDefaults())
    store.setBestProbability(1, 0.80)
    store.setBestProbability(2, 0.95)
    #expect(store.bestProbability(1) == 0.80)
    #expect(store.bestProbability(2) == 0.95)
}

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "test.\(UUID().uuidString)")!
}
```

(`makeDefaults` is used by the new tests; check if the existing test file already has a similar helper — if so, reuse it. If it uses `defaults: .standard` directly, keep new tests on suiteName to avoid polluting real state.)

- [ ] **Step 2: Run the new tests, confirm RED**

Run: `xcodebuild test-without-building ... -only-testing:llm-visualizerTests/LevelProgressTests`
Expected: 4 failures (`bestProbability(_:)` is not defined on `ProgressStore`).

- [ ] **Step 3: Add API to `ProgressStore`**

In `llm-visualizer/Models/LevelProgress.swift`, add the new private key and accessors:
```swift
private let bestKey = "llmviz.bestProbabilities"  // [Int: Double] encoded as [String: Double] plist

func bestProbability(_ levelId: Int) -> Double {
    bestMap[levelId] ?? 0.0
}

func setBestProbability(_ levelId: Int, _ value: Double) {
    var map = bestMap
    let clamped = max(0.0, min(1.0, value))
    if let existing = map[levelId], existing >= clamped { return }
    map[levelId] = clamped
    defaults.set(map, forKey: bestKey)
}

private var bestMap: [Int: Double] {
    (defaults.dictionary(forKey: bestKey) as? [String: Double])?
        .compactMapKeys { Int($0) } ?? [:]
}

private extension Dictionary where Key == String, Value == Double {
    func compactMapKeys<T>(_ transform: (String) -> T?) -> [T: Double] {
        var out: [T: Double] = [:]
        for (k, v) in self { if let nk = transform(k) { out[nk] = v } }
        return out
    }
}
```

Note: `compactMapKeys` is private and avoids naming a global helper. If the file already has similar plumbing, follow that pattern.

- [ ] **Step 4: Run tests, confirm GREEN**

Run `LevelProgressTests`. Expected: all 4 new tests pass; existing tests untouched.

- [ ] **Step 5: Wire into `Level1ViewModel`**

In `llm-visualizer/ViewModels/Level1ViewModel.swift`:

- Change initializer to accept a `ProgressStore` and load best on init:
  ```swift
  private let progressStore: ProgressStore

  init(service: LLMServiceProtocol, progressStore: ProgressStore = .shared) {
      self.service = service
      self.progressStore = progressStore
      self.bestSoFar = progressStore.bestProbability(1)
  }
  ```
- In `submit()`, replace:
  ```swift
  bestSoFar = max(bestSoFar, maxProb)
  ```
  with:
  ```swift
  if maxProb > bestSoFar {
      bestSoFar = maxProb
      progressStore.setBestProbability(1, maxProb)
  }
  ```
- Remove the now-unused `private var modelContainer: ModelContainer?` cache (will be removed fully in Task 17 — for now just leave it; the bootstrap/ensureContainer calls become no-ops).

- [ ] **Step 6: Update existing tests if any construct Level1ViewModel with a non-default store**

`Level1ViewModelTests.swift` uses `Level1ViewModel(service: mock)`. With the new default arg this still compiles, but its `bestSoFar` is loaded from `ProgressStore.shared` — which may carry values from a prior test run on a real device. Wrap the helper:

```swift
private func vm(stubbed: [TokenCandidate]) -> Level1ViewModel {
    let mock = MockLLMService()
    mock.stubbedPredictTopK = stubbed
    let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    return Level1ViewModel(service: mock, progressStore: store)
}
```

- [ ] **Step 7: Run full test target, confirm GREEN**

Run the full unit-test target. Expected: 50+ tests pass, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add llm-visualizer/Models/LevelProgress.swift \
        llm-visualizer/ViewModels/Level1ViewModel.swift \
        llm-visualizerTests/LevelProgressTests.swift \
        llm-visualizerTests/Level1ViewModelTests.swift
git commit -m "fix(Progress): persist Level 1 best probability across launches"
```

---

## Task 1: Remove dead `continueAfterPass` (P0.2)

**Files:**
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift`

- [ ] **Step 1: Confirm dead**

```bash
grep -r "continueAfterPass" llm-visualizer llm-visualizerTests
```

Expected: only the definition site in `Level1ViewModel.swift`. (The grep will also turn up hits in `docs/superpowers/` — those are spec/plan traces and we ignore them.)

- [ ] **Step 2: Delete the method**

In `Level1ViewModel.swift`, remove lines 67-70:
```swift
func continueAfterPass() {
    // Celebration dismissed; state stays .passed so the ✓ badge
    // remains in the header and the goal indicator doesn't re-suggest.
}
```

- [ ] **Step 3: Build, confirm GREEN**

Run: `xcodebuild build-for-testing ...` then `xcodebuild test-without-building -only-testing:llm-visualizerTests/Level1ViewModelTests`.
Expected: 7 tests pass, build clean.

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/ViewModels/Level1ViewModel.swift
git commit -m "refactor(Level1): drop unused continueAfterPass()"
```

---

## Task 2: Add Level 2 placeholder (P0.3)

**Files:**
- Create: `llm-visualizer/Models/Level2Session.swift`
- Create: `llm-visualizer/Views/Level2/Level2View.swift`
- Modify: `llm-visualizer/Models/Levels.swift`
- Modify: `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`
- Test: `llm-visualizerTests/Level2RegistryTests.swift` (new)
- Test: `llm-visualizerTests/LevelRegistryTests.swift` (extend)

- [ ] **Step 1: Write failing test in `Level2RegistryTests.swift`**

```swift
@MainActor
struct Level2RegistryTests {

    @Test func levelTwoIsInRegistry() {
        let ids = LevelRegistry.all.map { $0.init(id: 99, title: "", subtitle: "", goalDescription: "").id }
        #expect(ids.contains(2))
    }

    @Test func levelTwoIsCompleteByDefault() {
        let session = Level2Session()
        #expect(session.isComplete == false)
    }

    @Test func levelTwoContentViewRenders() {
        let session = Level2Session()
        let _ = session.makeContentView()
    }
}
```

Wait — `LevelRegistry.all` returns metatypes that take `(viewModel:)` style initializers, not the base 4-arg. Re-check `Level1Session.init`:
```swift
init(viewModel: Level1ViewModel)
```
It does not conform to the base 4-arg init. The base class `LevelSession` is `init(id:title:subtitle:goalDescription:)`. Subclasses like `Level1Session` override with their own custom init. `LevelRegistry.all` stores `[LevelSession.Type]`, and to call `init(...)` polymorphically the class needs a `@MainActor` `init()` or a factory. Today, `LevelRegistry` is unused (see LevelRegistryTests below). The test must use the actual factory used at runtime (`AppRootView` constructs `Level1Session(viewModel:)` directly).

This means the test for `Level2InRegistry` is harder than it looks. The right move is to make Level2Session conform to a *factory* the registry can call. But that's a bigger refactor than the scope of this PR. Instead, the minimum viable stub:

- Add `Level2Session` with a no-arg init that the test can construct directly.
- Update `LevelRegistry.all` to `[Level1Session.self, Level2Session.self]`.
- Tests assert registry contents via the type's existence in the array, not by trying to init through the protocol.

Rewrite the test file:

```swift
@MainActor
struct Level2RegistryTests {

    @Test func levelTwoIsInRegistry() {
        let names = LevelRegistry.all.map { String(describing: $0) }
        #expect(names.contains("Level2Session"))
    }

    @Test func levelTwoIsNotCompleteByDefault() {
        #expect(Level2Session().isComplete == false)
    }

    @Test func levelTwoContentViewRenders() {
        let _ = Level2Session().makeContentView()
    }
}
```

- [ ] **Step 2: Run, confirm RED**

Run `Level2RegistryTests`. Expected: 3 failures (`Level2Session` does not exist).

- [ ] **Step 3: Create `Level2Session`**

```swift
//
//  Level2Session.swift
//

import SwiftUI

@MainActor
final class Level2Session: LevelSession {

    init() {
        super.init(
            id: 2,
            title: String(localized: "Level 2", defaultValue: "Level 2"),
            subtitle: String(
                localized: "Coming soon",
                defaultValue: "Coming soon"
            ),
            goalDescription: String(
                localized: "Level 2 in progress",
                defaultValue: "Level 2 in progress"
            )
        )
    }

    override func makeContentView() -> AnyView {
        AnyView(Level2View())
    }
}
```

- [ ] **Step 4: Create `Level2View`**

```swift
//
//  Level2View.swift
//

import SwiftUI

struct Level2View: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String(
                localized: "Level 2 is on the way",
                defaultValue: "Level 2 is on the way"
            ))
            .font(.title2.weight(.bold))
            Text(String(
                localized: "We'll keep building. Stay tuned.",
                defaultValue: "We'll keep building. Stay tuned."
            ))
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    Level2View()
}
```

- [ ] **Step 5: Register in `LevelRegistry`**

In `llm-visualizer/Models/Levels.swift`:
```swift
static let all: [LevelSession.Type] = [
    Level1Session.self,
    Level2Session.self,
]
```

- [ ] **Step 6: Drop misleading copy in `PassCelebrationView`**

In `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`:
- Remove the trailing `Text(... "Next level is on the way" ...)` block (lines 54-57).
- Replace the button label with `String(localized: "Try again", defaultValue: "Try again")` is already present — keep it.

- [ ] **Step 7: Run `Level2RegistryTests`, confirm GREEN**

Run the new test class. Expected: 3 pass.

- [ ] **Step 8: Run full unit test suite, confirm no regressions**

Run all of `llm-visualizerTests`. Expected: 50+ pass, 0 fail.

- [ ] **Step 9: Commit**

```bash
git add llm-visualizer/Models/Level2Session.swift \
        llm-visualizer/Models/Levels.swift \
        llm-visualizer/Views/Level2/Level2View.swift \
        llm-visualizer/Views/LevelShell/PassCelebrationView.swift \
        llm-visualizerTests/Level2RegistryTests.swift
git commit -m "feat(Levels): add Level 2 placeholder + drop misleading 'next level on the way' copy"
```

---

## Task 3: Bilingual inspiration fragments (P0.4)

**Files:**
- Modify: `llm-visualizer/Views/Common/InspirationButtonsView.swift`
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Move fragments into `xcstrings`**

Add these keys (en + zh-Hans) via the Xcode String Catalog or by editing JSON:

| Key | en | zh-Hans |
|---|---|---|
| `inspiration.fragment.eat` | I like to eat | 我爱吃 |
| `inspiration.fragment.tomorrow` | Tomorrow I will go to | 明天我要去 |
| `inspiration.fragment.life` | The most important thing in life is | 人生最重要的是 |
| `inspiration.fragment.weather` | Today's weather is | 今天天气真 |
| `inspiration.fragment.sun` | The sun rises from the east | 太阳从东边 |
| `inspiration.fragment.math` | 2 + 2 = | 2 + 2 = |
| `inspiration.fragment.capital` | The capital of China is | 中国的首都是 |

To edit JSON, open `Localizable.xcstrings`, find the alphabetical insertion point for each key (the file is roughly sorted by key), and add an entry like:
```json
"inspiration.fragment.eat" : {
  "comment" : "Inspiration sentence fragment shown in Level 1 input bar",
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "I like to eat" } },
    "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "我爱吃" } }
  }
}
```

(If using Xcode UI is preferred, do that — the schema is the same.)

- [ ] **Step 2: Replace hardcoded `defaultFragments`**

In `llm-visualizer/Views/Common/InspirationButtonsView.swift`:
```swift
static let defaultFragments: [String] = [
    String(localized: "inspiration.fragment.eat", defaultValue: "I like to eat"),
    String(localized: "inspiration.fragment.tomorrow", defaultValue: "Tomorrow I will go to"),
    String(localized: "inspiration.fragment.life", defaultValue: "The most important thing in life is"),
    String(localized: "inspiration.fragment.weather", defaultValue: "Today's weather is"),
    String(localized: "inspiration.fragment.sun", defaultValue: "The sun rises from the east"),
    String(localized: "inspiration.fragment.math", defaultValue: "2 + 2 ="),
    String(localized: "inspiration.fragment.capital", defaultValue: "The capital of China is"),
]
```

- [ ] **Step 3: Build, run all tests, confirm GREEN**

The strings compile and the unit tests don't assert on the fragments (they use mock service). No test changes needed.

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/Views/Common/InspirationButtonsView.swift \
        llm-visualizer/Resources/Localizable.xcstrings
git commit -m "i18n(Inspiration): bilingual sentence fragments"
```

---

## Task 4: Drop duplicate best-record footer (P1.5)

**Files:**
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`

- [ ] **Step 1: Delete the `footer` view + its call site**

In `Level1View.swift`:
- Remove the `private var footer: some View { ... }` computed property (lines 95-115).
- Replace the call site `Spacer(minLength: 8); footer` in `body` with `Spacer()`.

- [ ] **Step 2: Build, run tests, confirm GREEN**

No test changes. Build and full test suite.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Level1/Level1View.swift
git commit -m "refactor(Level1): drop duplicate best-record footer (header already shows it)"
```

---

## Task 5: Submit button shows in-button spinner (P1.6)

**Files:**
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add accessibility key**

In `Localizable.xcstrings`:
```json
"Submit" : {
  "comment" : "Accessibility label for the submit button in Level 1.",
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Submit" } },
    "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "提交" } }
  }
}
```

- [ ] **Step 2: Replace submit button label with state-aware view**

In `Level1View.swift`, replace the Button block:
```swift
Button {
    Task { await viewModel.submit() }
} label: {
    if viewModel.isLoading {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.accentColor))
    } else {
        Image(systemName: "arrow.up")
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.accentColor))
    }
}
.buttonStyle(.plain)
.disabled(
    viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    || viewModel.isLoading
)
.accessibilityLabel(String(localized: "Submit", defaultValue: "Submit"))
```

- [ ] **Step 3: Build + test, confirm GREEN**

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/Views/Level1/Level1View.swift \
        llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Level1): in-button spinner during submit + VoiceOver label"
```

---

## Task 6: Narrator follows current top1 in passed state (P1.7)

**Files:**
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`
- Modify: `llm-visualizer/Views/Level1/NarratorLineView.swift`
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add narrator state to view model**

In `Level1ViewModel.swift`, add a computed property:
```swift
var currentSentiment: NarratorLineView.Sentiment {
    let top1 = topCandidates.first?.probability ?? 0
    let base = NarratorLineView.sentiment(for: top1)
    return state == .passed ? .passed(current: base) : base
}
```

- [ ] **Step 2: Extend `NarratorLineView.Sentiment`**

In `NarratorLineView.swift`:
```swift
enum Sentiment: Equatable {
    case high
    case medium
    case low
    case passed(current: Sentiment)   // "you passed; here's the current vibe"

    var text: String {
        switch self {
        case .high:
            return String(localized: "narrator.high", defaultValue: "This time AI seems pretty sure.")
        case .medium:
            return String(localized: "narrator.medium", defaultValue: "This time AI is a bit unsure.")
        case .low:
            return String(localized: "narrator.low", defaultValue: "This time AI is very hesitant — several words have similar scores.")
        case .passed(let current):
            let prefix = String(localized: "narrator.passedPrefix", defaultValue: "You passed — ")
            return prefix + current.text
        }
    }
}
```

Note: `passed(current:)` is a recursive case. `Equatable` synthesis on enums with associated values that are themselves `Equatable` works automatically when all associated types are `Equatable`. `Sentiment` is `Equatable` and `current: Sentiment` is also `Equatable`, so this compiles. If the compiler complains, add a manual `==`.

- [ ] **Step 3: Update call site in `Level1View`**

In `Level1View.swift`, replace the `NarratorLineView(...)` instantiation:
```swift
if showNarrator {
    NarratorLineView(sentiment: viewModel.currentSentiment)
        .padding(.bottom, 4)
}
```

- [ ] **Step 4: Add localization keys**

In `Localizable.xcstrings`:
| Key | en | zh-Hans |
|---|---|---|
| `narrator.high` | This time AI seems pretty sure. | 这次 AI 看起来挺有把握。 |
| `narrator.medium` | This time AI is a bit unsure. | 这次 AI 有点拿不准。 |
| `narrator.low` | This time AI is very hesitant — several words have similar scores. | 这次 AI 很犹豫——好几个词分数接近。 |
| `narrator.passedPrefix` | You passed — | 你已通关—— |

(Also delete the old `"This time AI..."` keys — the existing `xcstrings` has them as raw inline strings; remove their entries.)

- [ ] **Step 5: Build, run all tests, confirm GREEN**

- [ ] **Step 6: Commit**

```bash
git add llm-visualizer/ViewModels/Level1ViewModel.swift \
        llm-visualizer/Views/Level1/Level1View.swift \
        llm-visualizer/Views/Level1/NarratorLineView.swift \
        llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Narrator): follow current top1 in passed state with prefix"
```

---

## Task 7: Initial empty state guidance (P1.8)

**Files:**
- Create: `llm-visualizer/Views/Common/EmptyStateView.swift`
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add `EmptyStateView`**

```swift
//
//  EmptyStateView.swift
//

import SwiftUI

struct EmptyStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    EmptyStateView(message: "Type a sentence above. The bar shows how sure AI is.")
        .background(Color(.systemGroupedBackground))
}
```

- [ ] **Step 2: Add localization key**

| Key | en | zh-Hans |
|---|---|---|
| `level1.emptyState` | Type a sentence above — the bars below show how sure the AI is about its next word. | 在上方输入一句话，下方的概率条会显示 AI 对下一个词有多确定。 |

- [ ] **Step 3: Insert into `Level1View` body**

In `Level1View.swift`, wrap the `ProbabilityBarsView` in a conditional:
```swift
if viewModel.topCandidates.isEmpty {
    EmptyStateView(
        message: String(
            localized: "level1.emptyState",
            defaultValue: "Type a sentence above — the bars below show how sure the AI is about its next word."
        )
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 24)
} else {
    ProbabilityBarsView(
        candidates: viewModel.topCandidates,
        isPassed: viewModel.state == .passed
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
}
```

- [ ] **Step 4: Build + test, confirm GREEN**

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Views/Common/EmptyStateView.swift \
        llm-visualizer/Views/Level1/Level1View.swift \
        llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Level1): empty-state guidance before first submit"
```

---

## Task 8: Inspiration fragments append, not replace (P1.9)

**Files:**
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`
- Modify: `llm-visualizer/Views/Common/InspirationButtonsView.swift`

- [ ] **Step 1: Update `InspirationButtonsView` callback**

The `onTap` closure already passes the fragment string; behavior is owned by the caller. No API change needed in the view.

- [ ] **Step 2: Change call site to append**

In `Level1View.swift`, the existing call:
```swift
InspirationButtonsView(fragments: fragments) { fragment in
    viewModel.prompt = fragment
}
```

Replace with:
```swift
InspirationButtonsView(fragments: fragments) { fragment in
    let trimmed = viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        viewModel.prompt = fragment
    } else {
        viewModel.prompt = trimmed + fragment
    }
    // No @FocusState in this codebase yet; a future task could add one.
}
```

- [ ] **Step 3: Build + test, confirm GREEN**

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/Views/Level1/Level1View.swift
git commit -m "feat(Inspiration): append fragment to existing prompt instead of replacing"
```

---

## Task 9: Probability bar min width + 0% handling (P1.10)

**Files:**
- Modify: `llm-visualizer/Views/Level1/ProbabilityBarsView.swift`

This is a pure UI change with deterministic math; no test. The `probability` is a `Double` in `[0, 1]`. We need:
- A non-zero probability gets a visible bar of at least 4pt.
- A zero probability produces no bar (frame width 0).

- [ ] **Step 1: Replace `row(for:)` bar width calculation**

In `ProbabilityBarsView.swift`, replace:
```swift
RoundedRectangle(cornerRadius: 3)
    .fill(muted)
    .frame(width: geo.size.width * CGFloat(c.probability))
```

with:
```swift
RoundedRectangle(cornerRadius: 3)
    .fill(muted)
    .frame(width: barWidth(for: c.probability, in: geo.size.width))
```

And add a helper:
```swift
private func barWidth(for probability: Double, in total: CGFloat) -> CGFloat {
    if probability <= 0 { return 0 }
    return max(4, total * CGFloat(probability))
}
```

- [ ] **Step 2: Build + test, confirm GREEN**

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Level1/ProbabilityBarsView.swift
git commit -m "fix(ProbabilityBars): min 4pt width for non-zero, 0 for zero"
```

---

## Task 10: Number format + plural fix (P1.11)

**Files:**
- Modify: `llm-visualizer/Views/Level1/Level1View.swift` (none — footer is gone)
- Modify: `llm-visualizer/Resources/Localizable.xcstrings` (cleanup the entry)

Note: The "Submitted %d times" copy was on the deleted footer (P1.5). So P1.11 collapses to: drop the now-unused `Submitted %d times` localization key. (We never use plural inflection here, so no format change needed.)

- [ ] **Step 1: Find and delete the key**

```bash
grep -n "Submitted %d times\|Submitted " llm-visualizer/Resources/Localizable.xcstrings
```

Delete the matching entries. (No production code references them after Task 4.)

- [ ] **Step 2: Commit**

```bash
git add llm-visualizer/Resources/Localizable.xcstrings
git commit -m "chore(l10n): drop now-unused 'Submitted %d times' key"
```

---

## Task 11: Dynamic Type + accessibility (P2.12)

**Files:**
- Modify: `llm-visualizer/Views/Level1/ProbabilityBarsView.swift`
- Modify: `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`

- [ ] **Step 1: Replace hardcoded font sizes**

In `ProbabilityBarsView.swift`:
- `Text(top1?.text ?? "—").font(.system(size: 48, weight: .bold))` → `.font(.largeTitle.weight(.bold))`
- `Text(percentString(...)).font(.system(size: 22, weight: .semibold))` → `.font(.title2.weight(.semibold))`

In `PassCelebrationView.swift`:
- `Text("🏆").font(.system(size: 80))` → `.font(.system(size: 80))` (keep — emoji glyphs don't scale with Dynamic Type, intentional)
- `Text(... "You made AI...").font(.system(size: 28, weight: .bold))` → `.font(.title.weight(.bold))`
- `Text(... "When the context is clear enough...").font(.subheadline)` — already semantic; keep.

- [ ] **Step 2: Add VoiceOver labels to the probability bars**

In `ProbabilityBarsView.swift`, on each `row(for:)` add:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(c.text), \(Int((c.probability * 100).rounded())) percent")
```

And on the top-1 card:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(
    "\(top1?.text ?? "no prediction"), \(Int((top1?.probability ?? 0 * 100).rounded())) percent"
)
```

- [ ] **Step 3: Add a non-color-only pass indicator**

In `LevelHeaderView.swift`, the existing `✓` is the icon; that's already non-color. No change.

- [ ] **Step 4: Build + test, confirm GREEN**

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Views/Level1/ProbabilityBarsView.swift \
        llm-visualizer/Views/LevelShell/PassCelebrationView.swift
git commit -m "feat(a11y): Dynamic Type + VoiceOver labels for probability bars"
```

---

## Task 12: Localization cleanup (P2.13)

**Files:**
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Remove symbol-only entries**

```bash
grep -n '"·"\|"✓"\|"🏆"' llm-visualizer/Resources/Localizable.xcstrings
```

Delete the entries whose `value` is purely `·`, `✓`, or `🏆`. (These are inline symbols used directly in `LevelHeaderView`, `PassCelebrationView` — no need to localize.)

- [ ] **Step 2: Verify no code references them as keys**

```bash
grep -rn 'localized: "·"\|localized: "✓"\|localized: "🏆"' llm-visualizer
```

Expected: 0 hits. If any exist, inline the symbol instead.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Resources/Localizable.xcstrings
git commit -m "chore(l10n): drop non-localizable symbol-only entries"
```

---

## Task 13: Error humanization (P2.14)

**Files:**
- Create: `llm-visualizer/Models/LevelError.swift`
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Test: `llm-visualizerTests/LevelErrorTests.swift` (new)

- [ ] **Step 1: Write failing tests in `LevelErrorTests.swift`**

```swift
@MainActor
struct LevelErrorTests {

    @Test func modelNotReadyMapsToFriendlyMessage() {
        let e = LevelError.humanize(NSError(
            domain: "MLX", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Metal device not found"]
        ))
        #expect(e == "Model is still loading. Please wait a moment.")
    }

    @Test func emptyPromptMapsToFriendlyMessage() {
        let e = LevelError.humanize(NSError(
            domain: "Prompt", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "empty input"]
        ))
        // We don't have a specific empty-prompt case in the model path,
        // so this just falls through to the generic message.
        #expect(e.contains("Something went wrong"))
    }

    @Test func unknownErrorFallsBackToGeneric() {
        let e = LevelError.humanize(NSError(
            domain: "Other", code: 99,
            userInfo: [NSLocalizedDescriptionKey: "out of cheese"]
        ))
        #expect(e.contains("Something went wrong"))
    }
}
```

- [ ] **Step 2: Run, confirm RED**

- [ ] **Step 3: Create `LevelError`**

```swift
//
//  LevelError.swift
//

import Foundation

enum LevelError {
    static func humanize(_ error: Error) -> String {
        let raw = (error as NSError).localizedDescription.lowercased()
        if raw.contains("metal") || raw.contains("device not found") {
            return String(
                localized: "error.model.loading",
                defaultValue: "Model is still loading. Please wait a moment."
            )
        }
        if raw.contains("empty") || raw.contains("invalid input") {
            return String(
                localized: "error.prompt.empty",
                defaultValue: "Please type a sentence first."
            )
        }
        return String(
            localized: "error.generic",
            defaultValue: "Something went wrong. Please try again."
        )
    }
}
```

- [ ] **Step 4: Use in `Level1ViewModel.submit()`**

Replace `showError(error.localizedDescription)` with `showError(LevelError.humanize(error))`.

- [ ] **Step 5: Add localization keys**

| Key | en | zh-Hans |
|---|---|---|
| `error.model.loading` | Model is still loading. Please wait a moment. | 模型还在加载中,请稍等。 |
| `error.prompt.empty` | Please type a sentence first. | 请先输入一句话。 |
| `error.generic` | Something went wrong. Please try again. | 出错了,请重试。 |

- [ ] **Step 6: Run tests, confirm GREEN**

- [ ] **Step 7: Commit**

```bash
git add llm-visualizer/Models/LevelError.swift \
        llm-visualizer/ViewModels/Level1ViewModel.swift \
        llm-visualizer/Resources/Localizable.xcstrings \
        llm-visualizerTests/LevelErrorTests.swift
git commit -m "feat(Errors): humanize model/prompt errors before showing"
```

---

## Task 14: Input length limit (P2.15)

**Files:**
- Modify: `llm-visualizer/Views/Level1/Level1View.swift`

- [ ] **Step 1: Add a soft cap to the prompt**

The `TextField` already allows arbitrary length; we add an `.onChange(of: viewModel.prompt)` that trims to 200 chars. This avoids a hard `TextField(text: ... .onChange)` fight with the binding. (200 chars is a soft cap that comfortably fits the model's context.)

```swift
TextField(
    String(localized: "Type your sentence…", defaultValue: "Type your sentence…"),
    text: $viewModel.prompt
)
.onChange(of: viewModel.prompt) { _, newValue in
    if newValue.count > 200 {
        viewModel.prompt = String(newValue.prefix(200))
    }
}
```

- [ ] **Step 2: Build + test, confirm GREEN**

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/Level1/Level1View.swift
git commit -m "fix(Level1): cap input at 200 chars"
```

---

## Task 15: Celebration spring + echo prompt (P2.16 + P2.17)

**Files:**
- Modify: `llm-visualizer/Views/LevelShell/PassCelebrationView.swift`
- Modify: `llm-visualizer/Views/LevelShell/LevelShellView.swift`
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add an `echoedPrompt` parameter to `PassCelebrationView`**

```swift
struct PassCelebrationView: View {
    let echoedPrompt: String?
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ...
            VStack(spacing: 14) {
                ...
                if let prompt = echoedPrompt, !prompt.isEmpty {
                    VStack(spacing: 4) {
                        Text(String(
                            localized: "celebration.yourSentence",
                            defaultValue: "Your sentence"
                        ))
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        Text(prompt)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 8)
                }
                ...
            }
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}
```

- [ ] **Step 2: Wire from `LevelShellView`**

`LevelShellView.swift` is where the celebration is instantiated. Pass the latest prompt:
```swift
PassCelebrationView(
    echoedPrompt: (currentSession as? Level1Session)?.viewModel.prompt,
    onContinue: { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { dismissed = true } }
)
```

The spring on the dismiss matches the celebration's own entry feel. The `.transition` already exists on `PassCelebrationView`; the entry animation is driven by `LevelShellView`'s implicit transitions when `level1.viewModel.state` changes. Wrap the ZStack in a `withAnimation` on the celebration show:
```swift
.onChange(of: level1.viewModel.state) { _, new in
    if new == .passed, !dismissed {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { /* trigger */ }
    }
}
```

If the existing transition handles it, just leave the transition `.spring` in place and remove the `withAnimation` here.

- [ ] **Step 3: Add localization key**

| Key | en | zh-Hans |
|---|---|---|
| `celebration.yourSentence` | Your sentence | 你的句子 |

- [ ] **Step 4: Build + test, confirm GREEN**

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Views/LevelShell/PassCelebrationView.swift \
        llm-visualizer/Views/LevelShell/LevelShellView.swift \
        llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Celebration): echo user prompt + spring transition"
```

---

## Task 16: Settings sheet (P3-3 + P3-4)

**Files:**
- Create: `llm-visualizer/Views/Settings/SettingsView.swift`
- Modify: `llm-visualizer/ViewModels/AppShellViewModel.swift`
- Modify: `llm-visualizer/Views/Common/LevelHeaderView.swift`
- Modify: `llm-visualizer/Models/LevelProgress.swift`
- Modify: `llm-visualizer/Resources/Localizable.xcstrings`
- Test: `llm-visualizerTests/ProgressStoreResetTests.swift` (new)
- Test: `llm-visualizerTests/AppShellViewModelTests.swift` (extend)

- [ ] **Step 1: Write failing test in `ProgressStoreResetTests.swift`**

```swift
import Testing
@testable import llm_visualizer

@MainActor
struct ProgressStoreResetTests {

    @Test func resetClearsAllKeys() {
        let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.hasSeenOnboarding = true
        store.setComplete(1, true)
        store.setBestProbability(1, 0.9)
        store.reset()
        #expect(store.hasSeenOnboarding == false)
        #expect(store.isComplete(1) == false)
        #expect(store.bestProbability(1) == 0.0)
    }
}
```

- [ ] **Step 2: Run, confirm RED**

- [ ] **Step 3: Add `reset()` to `ProgressStore`**

```swift
func reset() {
    defaults.removeObject(forKey: seenOnboardingKey)
    defaults.removeObject(forKey: completedKey)
    defaults.removeObject(forKey: bestKey)
}
```

- [ ] **Step 4: Run, confirm GREEN**

- [ ] **Step 5: Add `reset` to `AppShellViewModel`**

```swift
func reset() {
    progressStore.reset()
    state = .ready(hasSeenOnboarding: false)
}
```

Extend `AppShellViewModelTests.swift`:
```swift
@Test func resetFromReadyClearsOnboardingAndProgress() async {
    let mock = MockLLMService()
    let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    store.hasSeenOnboarding = true
    store.setComplete(1, true)
    let appVM = AppShellViewModel(service: mock, progressStore: store, onboardingPrompt: "x")
    await appVM.bootstrap()
    appVM.reset()
    if case .ready(let hasSeen) = appVM.state {
        #expect(hasSeen == false)
    } else {
        Issue.record("expected .ready after reset")
    }
    #expect(store.isComplete(1) == false)
}
```

Run, confirm GREEN.

- [ ] **Step 6: Create `SettingsView`**

```swift
//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    let onReplayOnboarding: () -> Void
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(String(
                        localized: "settings.replayOnboarding",
                        defaultValue: "Replay onboarding"
                    )) {
                        onReplayOnboarding()
                        dismiss()
                    }
                }
                Section {
                    Button(role: .destructive) {
                        onReset()
                        dismiss()
                    } label: {
                        Text(String(
                            localized: "settings.resetProgress",
                            defaultValue: "Reset all progress"
                        ))
                    }
                } footer: {
                    Text(String(
                        localized: "settings.resetFooter",
                        defaultValue: "Clears onboarding state, completed levels, and best records."
                    ))
                }
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
        }
    }
}
```

- [ ] **Step 7: Add settings button to `LevelHeaderView`**

In `LevelHeaderView.swift`, add a `trailing: (() -> AnyView)?` slot:
```swift
struct LevelHeaderView<Menu: View>: View {
    let levelNumber: Int
    let subtitle: String
    let goalDescription: String
    let bestSoFar: Double
    let isComplete: Bool
    @ViewBuilder let menu: () -> Menu

    init(
        levelNumber: Int,
        subtitle: String,
        goalDescription: String,
        bestSoFar: Double,
        isComplete: Bool,
        @ViewBuilder menu: @escaping () -> Menu = { EmptyView() }
    ) {
        ...
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(titleText).font(.headline)
                Text("·").foregroundStyle(.secondary)
                Text(subtitle).font(.headline).foregroundStyle(.secondary)
                if isComplete { Text("✓")... }
                Spacer()
                menu()
            }
            ...
        }
    }
}
```

Then in `LevelShellView.swift`, supply the menu:
```swift
LevelHeaderView(
    levelNumber: currentSession.id,
    subtitle: currentSession.subtitle,
    goalDescription: currentSession.goalDescription,
    bestSoFar: bestSoFar,
    isComplete: currentSession.isComplete,
    menu: {
        Menu {
            Button(String(localized: "settings.title", defaultValue: "Settings")) {
                showSettings = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
)
.sheet(isPresented: $showSettings) {
    SettingsView(
        onReplayOnboarding: {
            appVM.reset()  // re-routes via hasSeenOnboarding=false
        },
        onReset: {
            appVM.reset()
        }
    )
}
```

(Yes, "replay onboarding" and "reset progress" share the same `reset()` for now. They could diverge later — for the first cut, both surface the same state and the user is sent through onboarding again. Add a TODO comment in the code.)

- [ ] **Step 8: Add localization keys**

| Key | en | zh-Hans |
|---|---|---|
| `settings.title` | Settings | 设置 |
| `settings.replayOnboarding` | Replay onboarding | 重新观看引导 |
| `settings.resetProgress` | Reset all progress | 重置所有进度 |
| `settings.resetFooter` | Clears onboarding state, completed levels, and best records. | 清除引导状态、关卡完成记录和最高分。 |

- [ ] **Step 9: Build + run all tests, confirm GREEN**

- [ ] **Step 10: Commit**

```bash
git add llm-visualizer/Views/Settings/SettingsView.swift \
        llm-visualizer/ViewModels/AppShellViewModel.swift \
        llm-visualizer/Models/LevelProgress.swift \
        llm-visualizer/Views/Common/LevelHeaderView.swift \
        llm-visualizer/Resources/Localizable.xcstrings \
        llm-visualizerTests/ProgressStoreResetTests.swift \
        llm-visualizerTests/AppShellViewModelTests.swift
git commit -m "feat(Settings): replay onboarding + reset progress (sheet from header)"
```

---

## Task 17: LLMService dedupe container cache (P3-2)

**Files:**
- Modify: `llm-visualizer/ViewModels/Level1ViewModel.swift`
- Modify: `llm-visualizer/Services/LLMService.swift`
- Test: `llm-visualizerTests/MockLLMServiceTests.swift` (extend)
- Test: `llm-visualizerTests/Level1ViewModelTests.swift` (extend)

- [ ] **Step 1: Write failing test on `Level1ViewModel.submit()` re-uses the service container**

```swift
@Test func submitDoesNotCallLoadModelAgain() async {
    let mock = MockLLMService()
    mock.stubbedPredictTopK = [TokenCandidate(id: 1, text: "x", probability: 0.5)]
    let store = ProgressStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    let v = Level1ViewModel(service: mock, progressStore: store)
    _ = try? await mock.loadModel()  // pre-load
    #expect(mock.loadModelCallCount == 1)
    v.prompt = "hi"
    await v.submit()
    #expect(mock.loadModelCallCount == 1)  // no re-load
}
```

- [ ] **Step 2: Run, confirm RED**

Expected: fail (the current `Level1ViewModel.ensureContainer()` will call `loadModel` a second time if `modelContainer` is nil and the service cache is set independently).

- [ ] **Step 3: Drop the duplicate cache**

In `Level1ViewModel.swift`:
- Delete `private var modelContainer: ModelContainer?`.
- Delete `func bootstrap()`.
- Delete `private func ensureContainer()`.
- In `submit()`, change:
  ```swift
  let container = try await ensureContainer()
  let candidates = try await service.predictNextTokens(prompt: trimmed, topK: 4)
  ```
  to:
  ```swift
  let candidates = try await service.predictNextTokens(prompt: trimmed, topK: 4)
  ```
  (`predictNextTokens` already calls `ensureContainer` internally, line 94 of `LLMService.swift`.)

- [ ] **Step 4: Check `Level1Session`**

`Level1Session.swift` does not call `bootstrap()`. Safe to proceed.

- [ ] **Step 5: Run the new test, confirm GREEN**

- [ ] **Step 6: Run full suite, confirm GREEN**

- [ ] **Step 7: Commit**

```bash
git add llm-visualizer/ViewModels/Level1ViewModel.swift \
        llm-visualizerTests/Level1ViewModelTests.swift
git commit -m "refactor(Level1): drop duplicate model container cache (service owns it)"
```

---

## Task 18: README (P3-1)

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

```markdown
# LLM Visualizer

An iOS app that turns an LLM into a tactile teaching toy. Each "level" poses a tiny
challenge about how the model thinks; you play by typing sentences and reading
the model's probability distribution.

## Levels

| # | Title | Goal |
|---|-------|------|
| 1 | Make AI guess right with its eyes closed | Find a sentence where the model's Top-1 next-token probability is > 90%. |
| 2 | Coming soon | — |

## Stack

- SwiftUI + `@Observable`
- MLX (`mlx-swift`, `mlx-swift-lm`) — runs Qwen3-0.6B 4-bit on-device
- Swift Testing

## Run

```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Test

```bash
DD=~/Library/Developer/Xcode/DerivedData/llm-visualizer-XXXX
xcodebuild test-without-building -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=…' \
  -derivedDataPath "$DD" -only-testing:llm-visualizerTests
```

## Localization

`llm-visualizer/Resources/Localizable.xcstrings` (en + zh-Hans).

## Project layout

```
llm-visualizer/
  Models/        # LevelSession, Level1Session, Level2Session, ProgressStore, …
  Services/      # LLMService, MockLLMService
  ViewModels/    # @Observable, @MainActor
  Views/
    Common/      # LevelHeaderView, InspirationButtonsView, EmptyStateView
    LevelShell/  # LevelShellView, PassCelebrationView
    Level1/      # Level1View, ProbabilityBarsView, NarratorLineView
    Level2/      # Level2View (placeholder)
    Onboarding/  # ExampleCardView, OnboardingFlowView
    Loading/     # ModelLoadingView
    Settings/    # SettingsView
    Chat/        # free chat (Level 1 pre-cursor)
llm-visualizerTests/  # Swift Testing
```
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Task 19: Final full-suite verification

- [ ] **Step 1: Run the full unit-test target**

```bash
DD=~/Library/Developer/Xcode/DerivedData/llm-visualizer-eppqmoleaocfdfgffvckcujzdqbd
xcodebuild build-for-testing -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=9B6D70A2-34DC-4E1E-B8FE-9058FCE77307' \
  -derivedDataPath "$DD"
xcodebuild test-without-building -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=9B6D70A2-34DC-4E1E-B8FE-9058FCE77307' \
  -derivedDataPath "$DD" -only-testing:llm-visualizerTests
```

Expected: every test passes, 0 failures. (Should be 50+ tests, up from the original 50 due to new tests added across tasks.)

- [ ] **Step 2: Build the UI test target too**

```bash
xcodebuild build -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=9B6D70A2-34DC-4E1E-B8FE-9058FCE77307' \
  -derivedDataPath "$DD" -only-testing:llm-visualizerUITests
```

(UI tests require the model to load; not running them in CI, but compile must pass.)

- [ ] **Step 3: `git log --oneline main..HEAD`**

Verify all 19 task commits present. Squash if user prefers.

- [ ] **Step 4: Push branch & open PR**

```bash
git push origin fix/level1-ux-polish
gh pr create --base main --title "Level 1 UX polish" --body "Fixes 19 issues from the PM review (P0–P3)."
```

---

## Self-review notes

- **Spec coverage:** Every PM review item maps to a task. P0 1–4, P1 5–11, P2 12–17, P3-1/2/3/4 = 19 items.
- **Type consistency:** `Sentiment.passed(current:)` recursively references `Sentiment`; OK because `Equatable` synthesis handles nested `Equatable`. `LevelHeaderView<Menu: View>` is a new generic signature; the existing call site in `LevelShellView` is updated in Task 16.
- **Dependency ordering:** P0.1 (best persistence) → P1.5 (drop footer) is the only cross-task ordering constraint; everything else is independent.
- **Localization:** All new keys are listed in tasks with en + zh-Hans values. Symbols `·` `✓` `🏆` are removed from the catalog (Task 12) — they are inlined literals in the view code.
- **MLX dependency:** No tasks touch MLX APIs. Task 17 removes duplicate caching but still uses the same `service.predictNextTokens` call.

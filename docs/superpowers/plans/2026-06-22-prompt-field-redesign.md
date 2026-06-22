# Prompt Field Redesign + StatusBar Status LED — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic `PromptField` look with a ChatGPT-like rounded-rect + external blue square button, and add a colored status LED (with loading-state pulse) to `StatusBar`.

**Architecture:** Visual-only refactor. Two new reusable primitives (`PromptSendButtonStyle: ButtonStyle` and `PromptFieldBackground: ViewModifier`) own the look; `PromptField` becomes a thin composition that calls them. The disabled-state "faded blue" is baked into the ButtonStyle via `@Environment(\.isEnabled)` so the parent view never computes opacity. The status LED is a private `statusDot` helper inside `StatusBar`, driven by a `@State pulseOn` toggled by `.onChange(of: modelState)` and animated via `.animation(_:value:)`.

**Tech Stack:** Swift 5.9+ / iOS 17.0+, SwiftUI (`ButtonStyle`, `ViewModifier`, `.animation(_:value:)`), XCTest for UI tests, Swift Testing is **not** used for this plan since the changes are visual-only and have no new unit-testable behavior.

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-22-prompt-field-redesign.md`
- Existing chat plan: `docs/superpowers/plans/2026-06-21-llm-visualizer-chat.md` (style + commit cadence match this)

---

## Task 1: Create `PromptSendButtonStyle`

**Files:**
- Create: `llm-visualizer/Views/PromptSendButtonStyle.swift`

No unit test — `ButtonStyle` is visual; verified via UI test in Task 6 and manual check in Task 7.

- [ ] **Step 1: Create the file**

Create `llm-visualizer/Views/PromptSendButtonStyle.swift`:

```swift
//
//  PromptSendButtonStyle.swift
//

import SwiftUI

struct PromptSendButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                color.opacity(configuration.isPressed ? 0.7 : 1.0),
                in: .rect(cornerRadius: 12)
            )
            .opacity(isEnabled ? 1.0 : 0.35)
    }

    @Environment(\.isEnabled) private var isEnabled
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED. (The new file is auto-discovered by Xcode via the synchronized-folder group; if it isn't, drag it into the `Views` group in the project navigator.)

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/PromptSendButtonStyle.swift
git commit -m "feat(Views): PromptSendButtonStyle with built-in disabled fade"
```

---

## Task 2: Create `PromptFieldBackground`

**Files:**
- Create: `llm-visualizer/Views/PromptFieldBackground.swift`

No unit test — `ViewModifier` is visual; verified manually in Task 7.

- [ ] **Step 1: Create the file**

Create `llm-visualizer/Views/PromptFieldBackground.swift`:

```swift
//
//  PromptFieldBackground.swift
//

import SwiftUI

struct PromptFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(.white, in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/PromptFieldBackground.swift
git commit -m "feat(Views): PromptFieldBackground modifier (white + separator stroke)"
```

---

## Task 3: Rewrite `PromptField`

**Files:**
- Modify: `llm-visualizer/Views/PromptField.swift` (full rewrite — same public API)

No new unit test — the public API (`prompt`, `isGenerating`, `canSend`, `onSend`) is unchanged; existing UI tests cover the wiring (Task 6).

- [ ] **Step 1: Replace the file contents**

Replace `llm-visualizer/Views/PromptField.swift` with:

```swift
//
//  PromptField.swift
//

import SwiftUI

struct PromptField: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Ask anything…", text: $prompt, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }
                .modifier(PromptFieldBackground())

            Button(action: onSend) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(PromptSendButtonStyle())
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityLabel("Send")
        }
    }
}
```

Notes:
- Placeholder text changed from `"Prompt"` → `"Ask anything…"` (intentional copy change).
- `.accessibilityLabel("Send")` is added so UI tests can target the button reliably.
- `.keyboardShortcut(.return, modifiers: [])` is preserved from the original.

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/PromptField.swift
git commit -m "feat(Views): redesign PromptField (ChatGPT-like rounded rect + blue square send)"
```

---

## Task 4: Update `ChatView` Padding

**Files:**
- Modify: `llm-visualizer/Views/ChatView.swift` (one-line padding change)

- [ ] **Step 1: Edit the padding**

In `llm-visualizer/Views/ChatView.swift`, find:

```swift
                PromptField(
                    prompt: $viewModel.prompt,
                    isGenerating: viewModel.isGenerating,
                    canSend: !viewModel.isGenerating
                        && !viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && viewModel.modelState == .loaded,
                    onSend: {
                        Task { await viewModel.generate() }
                    }
                )
                .padding()
```

Replace `.padding()` (the last line) with:

```swift
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
```

The full block should now read:

```swift
                PromptField(
                    prompt: $viewModel.prompt,
                    isGenerating: viewModel.isGenerating,
                    canSend: !viewModel.isGenerating
                        && !viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && viewModel.modelState == .loaded,
                    onSend: {
                        Task { await viewModel.generate() }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/ChatView.swift
git commit -m "fix(Views): tighten PromptField padding (flush with conversation edges)"
```

---

## Task 5: Add Status LED to `StatusBar`

**Files:**
- Modify: `llm-visualizer/Views/StatusBar.swift`

No unit test — the LED is visual; verified manually in Task 7.

- [ ] **Step 1: Add the pulse state**

In `llm-visualizer/Views/StatusBar.swift`, inside the `StatusBar` struct (alongside any other `@State` you may add later), add:

```swift
    @State private var pulseOn = false
```

- [ ] **Step 2: Add the `statusDot` helper**

Inside `StatusBar`, add this private helper (next to the existing `statusText` helper):

```swift
    @ViewBuilder
    private func statusDot(_ state: ChatViewModel.ModelState,
                            isGenerating: Bool) -> some View {
        let color: Color = {
            switch state {
            case .idle:    return .gray
            case .loading: return .orange
            case .loaded:
                return isGenerating ? .accentColor : .green
            case .error:   return .red
            }
        }()
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
            .opacity(pulseOn ? 0.45 : 1.0)
            .animation(
                pulseOn
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : nil,
                value: pulseOn
            )
    }
```

- [ ] **Step 3: Wrap each `statusText` branch with an HStack containing the dot**

In the `statusText` computed property, prepend an `HStack(spacing: 6) { statusDot(modelState, isGenerating: isGenerating); <existing content> }` around each branch's content. Replace the entire `statusText` computed property with:

```swift
    @ViewBuilder
    private var statusText: some View {
        switch modelState {
        case .idle:
            HStack(spacing: 6) {
                statusDot(modelState, isGenerating: false)
                Text("Initializing…")
            }
        case .loading:
            HStack(spacing: 6) {
                statusDot(modelState, isGenerating: false)
                ProgressView().controlSize(.small)
                Text("Loading model…")
            }
        case .loaded:
            if isGenerating {
                HStack(spacing: 6) {
                    statusDot(modelState, isGenerating: true)
                    Label(String(format: "Generating · %.1f t/s", tokensPerSecond),
                          systemImage: "circle.fill")
                        .foregroundStyle(.tint)
                }
            } else {
                HStack(spacing: 6) {
                    statusDot(modelState, isGenerating: false)
                    Text("Ready")
                        .foregroundStyle(.secondary)
                }
            }
        case .error(let message):
            HStack(spacing: 6) {
                statusDot(modelState, isGenerating: false)
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderless)
            }
        }
    }
```

- [ ] **Step 4: Wire the pulse lifecycle**

In the `body` computed property of `StatusBar`, add the `.onAppear` and `.onChange(of: modelState)` modifiers at the end of the modifier chain (after `.background(.bar)`). The chain becomes:

```swift
        HStack(spacing: 12) {
            statusText
                .frame(maxWidth: .infinity, alignment: .leading)

            if isGenerating {
                Button(action: onCancel) {
                    Label("Stop", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }

            if canReset {
                Button(action: onReset) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear { pulseOn = (modelState == .loading) }
        .onChange(of: modelState) { _, new in pulseOn = (new == .loading) }
```

- [ ] **Step 5: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add llm-visualizer/Views/StatusBar.swift
git commit -m "feat(Views): colored status LED on StatusBar with loading pulse"
```

---

## Task 6: Update UI Tests

**Files:**
- Modify: `llm-visualizerUITests/llm_visualizerUITests.swift`

- [ ] **Step 1: Update the placeholder in `testEmptyState`**

In `llm-visualizerUITests/llm_visualizerUITests.swift`, find:

```swift
    func testEmptyState() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["LLM Visualizer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Prompt"].exists)
    }
```

Replace `app.textFields["Prompt"]` with `app.textFields["Ask anything…"]`:

```swift
    func testEmptyState() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["LLM Visualizer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Ask anything…"].waitForExistence(timeout: 10))
    }
```

Added `waitForExistence(timeout: 10)` to match the pattern used for the title (placeholder isn't visible until the model finishes loading on first launch — `.exists` can race the lazy render).

- [ ] **Step 2: Add a new simulator-safe test for the disabled send button**

Append this test inside the `llm_visualizerUITests` class (above the closing `}`):

```swift
    func testSendButtonDisabledWhenEmpty() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Ask anything…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 10))
        XCTAssertFalse(sendButton.isEnabled, "Send button should be disabled when prompt is empty")
    }
```

- [ ] **Step 3: Run UI tests on the simulator**

In Xcode, select a simulator (iPhone 15, iOS 17+) as the test destination. Cmd-U. Expected:
- `testEmptyState` passes (placeholder now matches)
- `testSendButtonDisabledWhenEmpty` passes
- `testStatusBarTransitionsToReady` and `testSendAndReceive` still report as skipped (device-only)

- [ ] **Step 4: Commit**

```bash
git add llm-visualizerUITests/llm_visualizerUITests.swift
git commit -m "test(UI): update placeholder text + add send-disabled test"
```

---

## Task 7: Manual End-to-End Verification (Simulator)

**Files:** none (manual check only)

This task is a checklist for the engineer to confirm the visuals match the spec on a running simulator. No commit.

- [ ] **Step 1: Cold launch on simulator**

Run on iPhone 15 (iOS 17+) simulator. Open `llm-visualizer.xcodeproj`, select the `llm-visualizer` scheme, destination iPhone 15 simulator, Cmd-R.

Expected sequence:
1. Status bar shows **gray dot** + "Initializing…" for a beat
2. Status bar switches to **orange pulsing dot** + "Loading model…" (pulse should be clearly visible — opacity oscillating between full and ~half)
3. Status bar settles to **green dot** + "Ready" (pulse stops)
4. Input bar is visible at the bottom: white rounded-rect text field ("Ask anything…") on the left, blue square button with white up-arrow on the right

- [ ] **Step 2: Verify send button states**

5. With the field empty, the send button is **faded blue** (visibly lighter than the active state, still tinted blue — not gray)
6. Tap the text field, type "Hello". The send button becomes **solid blue** (clearly more saturated than the empty state)
7. Tap the send button. The prompt clears, button returns to **faded blue** (assuming the model is responding and `isGenerating` flips true)
8. While a message is generating, the status bar shows **blue dot** + "Generating · X.X t/s" and a Stop button on the right

- [ ] **Step 3: Verify dark mode**

9. In Simulator → Features → Toggle Appearance → Dark. Expected:
   - Text field background stays **white** (by design — see spec §7)
   - Separator stroke around the field is **subtler but visible**
   - Send button stays **blue** (system tint adapts)
   - LED colors (green / orange / red / gray / blue) all read correctly

- [ ] **Step 4: Verify long-prompt cap**

10. Tap the field, paste/type a prompt longer than 4 lines (e.g. a paragraph of lorem ipsum).
    Expected: the field grows to 4 lines tall and **caps** — content scrolls inside the field, no further vertical growth.

- [ ] **Step 5: Verify cancel / reset still work**

11. While generating, tap **Stop**. Expected: assistant message ends with `[Cancelled]`; status dot returns to green.
12. After at least one turn, tap the **trash** icon (top-right of status bar). Expected: messages clear, only the system message remains.

If any check fails, fix the underlying view and re-run from Step 1. Do not modify tests to mask a visual failure.

---

## Self-Review Checklist

After executing all tasks, verify:

- [ ] **Spec coverage:**
  - Layout B (rounded-rect field + external square blue button): Tasks 3
  - Send button color = `Color.accentColor` solid: Task 1, 3
  - Pressed state at 70% opacity: Task 1 (`configuration.isPressed ? 0.7 : 1.0`)
  - Disabled state at 35% opacity (faded blue, not gray): Task 1 (`@Environment(\.isEnabled)` → `.opacity(0.35)`)
  - Text field white bg + 0.5px `Color(.separator)` stroke + radius 12 + 8/12 padding + 40pt min height: Task 2
  - Placeholder "Ask anything…": Task 3
  - Container flush with chat area, no separator, no extra background: Task 4
  - Return / `.submitLabel(.send)` sends: Task 3 (preserved from original)
  - LED color mapping (gray/orange/green/blue/red per state): Task 5 step 2 + 3
  - Loading-state 0.6s ease-in-out pulse, repeats forever while `.loading`: Task 5 steps 1–4
  - Pulse stops on state change out of `.loading`: Task 5 step 4 (`.animation(_:value:)` with `nil` when `pulseOn == false`)
  - LED is a 9pt Circle with 0.5pt inset black stroke: Task 5 step 2
  - Dark-mode behavior (white field intentional, semantic colors adapt): covered by visual check in Task 7 step 3

- [ ] **Tests:**
  - `testEmptyState` updated to new placeholder text: Task 6 step 1
  - New simulator-safe `testSendButtonDisabledWhenEmpty`: Task 6 step 2
  - Skipped tests remain skipped (device-only): untouched in Task 6

- [ ] **Commit cadence:** 6 commits (Tasks 1–6), 0 commits for Task 7 (manual only) — matches the existing project style of one commit per file/concern.

- [ ] **No pbxproj edits expected:** Xcode's synchronized folders should auto-pick-up the two new `.swift` files. If `Cmd-B` reports "Cannot find 'PromptSendButtonStyle' in scope", open the project navigator and drag the two new files from `llm-visualizer/Views/` into the project's `Views` group, then commit the resulting `project.pbxproj` change as a follow-up.

- [ ] **Manual checklist all green** (Task 7).

- [ ] **No regressions:** existing tests still pass (skipped device-only tests stay skipped; `testEmptyState` and `testSendButtonDisabledWhenEmpty` pass).
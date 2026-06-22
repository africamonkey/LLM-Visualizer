# Auto-Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-scroll the conversation to the bottom while the assistant streams, while letting the user scroll up to read history without being yanked back.

**Architecture:** `ConversationView` is wrapped in a `ScrollViewReader` that captures a `ScrollViewProxy`. Two `.onChange` handlers trigger scrolling: count changes (user sent) force-scroll; content changes (streaming) scroll only if `isAtBottom` is true. `isAtBottom` flips via `.onAppear` / `.onDisappear` on the last message. A small `JumpToBottomButton` overlay appears when `!isAtBottom`, scrolls to bottom, and re-engages follow.

**Tech Stack:** Swift 5.9+ / iOS 17.0+, SwiftUI (`ScrollViewReader`, `ScrollViewProxy`, `withAnimation`, `.onChange(of:)`, `.onAppear`, `.onDisappear`, `.symbolEffect`), iOS 17+ SF Symbol bounce.

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-22-auto-scroll-during-generation.md`
- Sibling files for style: `llm-visualizer/Views/PromptSendButtonStyle.swift`, `llm-visualizer/Views/ThinkingBlock.swift`

---

## Task 1: `JumpToBottomButton` component

**Files:**
- Create: `llm-visualizer/Views/JumpToBottomButton.swift`

No unit test — the component is purely visual; verified manually in Task 3.

- [ ] **Step 1: Create the file**

Create `llm-visualizer/Views/JumpToBottomButton.swift`:

```swift
//
//  JumpToBottomButton.swift
//

import SwiftUI

struct JumpToBottomButton: View {
    let action: () -> Void
    @State private var tapCounter: Int = 0

    var body: some View {
        Button {
            tapCounter += 1
            action()
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: .circle)
                .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce, value: tapCounter)
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

If the build fails because Xcode can't find `JumpToBottomButton` in scope, the new file is not yet picked up by the project's synchronized folder. Open `llm-visualizer.xcodeproj` in Xcode, drag the file from Finder into the `Views` group in the project navigator, then re-run the build. (In practice this auto-discovery has worked in previous tasks; the fallback is only needed if Xcode hasn't indexed the new file yet.)

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/JumpToBottomButton.swift
git commit -m "feat(Views): JumpToBottomButton with bounce effect"
```

---

## Task 2: Wire `ConversationView` auto-scroll

**Files:**
- Modify: `llm-visualizer/Views/ConversationView.swift`

No new unit test — the change is SwiftUI lifecycle behavior; verified manually in Task 3.

- [ ] **Step 1: Read the current `ConversationView.swift`**

Read `/Users/africamonkey/work/llm-visualizer/llm-visualizer/Views/ConversationView.swift` to confirm the current state.

- [ ] **Step 2: Replace the file contents**

Replace `llm-visualizer/Views/ConversationView.swift` with:

```swift
//
//  ConversationView.swift
//

import SwiftUI

struct ConversationView: View {
    let messages: [Message]
    @State private var isAtBottom: Bool = true

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .onAppear {
                                    if message.id == messages.last?.id {
                                        isAtBottom = true
                                    }
                                }
                                .onDisappear {
                                    if message.id == messages.last?.id {
                                        isAtBottom = false
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { _, _ in
                    // New message appended (user just sent) — force scroll
                    if let last = messages.last {
                        isAtBottom = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages.last?.content) { _, _ in
                    // Last message content changed (streaming) — follow if at bottom
                    guard isAtBottom, let last = messages.last else { return }
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }

                if !isAtBottom {
                    JumpToBottomButton {
                        if let last = messages.last {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        isAtBottom = true
                    }
                    .padding(.bottom, 16)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run existing unit tests to confirm no regression**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO -only-testing:llm-visualizerTests/ThinkingParserTests -only-testing:llm-visualizerTests/MessageTests 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` with 11/11 tests passing (6 + 5).

If iPhone 16 is not available, try iPhone 17 / iPhone 16e / iPhone 15. Report which simulator ran.

If no simulator is available, fall back to:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
Expected: `** TEST BUILD SUCCEEDED **`. Report this as fallback in your self-review.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Views/ConversationView.swift
git commit -m "feat(Views): ConversationView auto-scroll + jump-to-bottom overlay"
```

---

## Task 3: Manual end-to-end verification

**Files:** none (manual check only)

This is a checklist to confirm the auto-scroll behavior matches the spec on a running simulator. No commit.

- [ ] **Step 1: Cold launch on simulator**

Run on iPhone 15 / 16 / 16e / 17 (iOS 17+) simulator. Open `llm-visualizer.xcodeproj`, select the `llm-visualizer` scheme, destination any iOS 17+ simulator, Cmd-R.

Expected:
1. App launches, model loads, status bar shows green dot + "Ready"
2. Conversation area shows the system message, scrolled to bottom
3. No jump-to-bottom button is visible

- [ ] **Step 2: Send a message, verify auto-scroll on send**

Send a short prompt like "hi".

Expected:
- Conversation auto-scrolls to the new user message + the assistant's response
- No jump-to-bottom button appears (we're at the bottom)

- [ ] **Step 3: Send a longer prompt, verify follow-during-streaming**

Send a reasoning-style prompt that elicits a thinking block and a long response (e.g. "用三步解释为什么天空是蓝色的").

Expected:
- ThinkingBlock appears and streams in
- After `</think>`, the answer bubble starts streaming in
- The conversation area continuously scrolls to follow the bottom of the answer bubble
- Scroll motion is smooth (linear, 100ms) — no jank, no overshoot

- [ ] **Step 4: Scroll up mid-streaming, verify follow stops**

While the assistant is still streaming, swipe up in the conversation area to read earlier messages.

Expected:
- The scroll stops following — it stays where you left it
- The jump-to-bottom button appears in the bottom-right corner
- The button has a blue circle with a down arrow, soft shadow, light border
- The button has a subtle appear animation (scale + fade in)

- [ ] **Step 5: Manually scroll back down, verify auto-re-engage**

While the assistant is still streaming, swipe down past the last message so it becomes visible again.

Expected:
- The jump-to-bottom button disappears
- The conversation starts auto-following again (subsequent tokens scroll into view)

- [ ] **Step 6: Tap the jump-to-bottom button**

After scrolling up enough to see the jump-to-bottom button, tap it.

Expected:
- The conversation scrolls smoothly to the bottom (0.2s ease-in-out)
- The arrow icon does a bounce animation (iOS 17 SF Symbol `.bounce`)
- The button disappears (scaling + fading out)
- Auto-follow resumes for any subsequent tokens

- [ ] **Step 7: Verify Stop / Reset still work**

While the assistant is generating, tap Stop in the status bar.

Expected: `[Cancelled]` is appended to the answer bubble; auto-follow continues if the user is at the bottom.

After at least one full turn, tap Reset.

Expected: messages clear, only the system message remains, scroll position is at the bottom, no jump button.

- [ ] **Step 8: Dark mode check**

In Simulator → Features → Toggle Appearance → Dark.

Expected:
- The jump-to-bottom button background still uses `Color.accentColor` (system tint, adapts)
- The border (`Color(.separator)`) is visible in both light and dark mode
- The shadow is subtle but visible in both modes

- [ ] **Step 9: Cycle the state several times**

Repeat the scroll-up / scroll-down / button-tap cycle several times.

Expected: state is stable; no leaks; no jitter.

---

## Self-Review Checklist

After executing all tasks, verify:

- [ ] **Spec coverage:**
  - `@State isAtBottom` (default `true`): Task 2 §5.2
  - `.id(message.id)` on each `MessageView`: Task 2 §5.2
  - `.onAppear` / `.onDisappear` on last message flipping `isAtBottom`: Task 2 §5.2
  - `.onChange(of: messages.count)` force-scroll + set `isAtBottom = true`: Task 2 §5.2
  - `.onChange(of: messages.last?.content)` conditional scroll (guard `isAtBottom`): Task 2 §5.2
  - `.defaultScrollAnchor(.bottom)` retained: Task 2 §5.2
  - `JumpToBottomButton` (36pt, accent color, `arrow.down` icon, separator border, shadow): Task 1 §5.1
  - Button position (bottom-right, 16/12 padding): Task 2 §5.2
  - Button appear/disappear transition (`.scale.combined(with: .opacity)`): Task 2 §5.2
  - Bounce on tap (`.symbolEffect(.bounce, value: tapCounter)`): Task 1 §5.1
  - Follow-during-streaming animation (`.linear(duration: 0.1)`): Task 2 §5.2
  - Jump-to-bottom animation (`.easeInOut(duration: 0.2)`): Task 2 §5.2
  - Jump-to-bottom action: scroll + set `isAtBottom = true`: Task 2 §5.2
  - Dark mode auto-adapts (semantic colors only): Tasks 1 & 2 use `Color.accentColor` and `Color(.separator)`
  - Existing unit tests (ThinkingParserTests 6/6, MessageTests 5/5) still pass: Task 2 step 4

- [ ] **No pbxproj edits expected** — Xcode's synchronized folders should auto-pick-up the new file. If `Cmd-B` reports a scope error, drag the file into the project navigator as Task 1 step 2 describes.

- [ ] **Commit cadence:** 2 commits (Tasks 1–2), 0 commits for Task 3 (manual only). Matches the spec §10 rollout plan.

- [ ] **Manual checklist all green** (Task 3).

- [ ] **No regressions:** all existing unit tests still pass.
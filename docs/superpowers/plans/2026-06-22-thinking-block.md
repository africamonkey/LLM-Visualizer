# Thinking Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the `<think>...</think>` block from assistant messages as a collapsible card above the actual answer bubble.

**Architecture:** Pure data parser (`ThinkingParser`) in `Models/` extracts the thinking and answer substrings from raw streamed content. A new `ThinkingBlock` view component renders the thinking portion as a collapsible accordion (default expanded). `MessageView.assistant` calls the parser and composes ThinkingBlock + answer bubble. TDD is used for the parser (pure function); visual components are verified manually.

**Tech Stack:** Swift 5.9+ / iOS 17.0+, SwiftUI (`@State`, `Button`, `withAnimation`, `.transition`), Swift Testing (`@Test`, `#expect`), Foundation (`String.range(of:)`, `String.replacingOccurrences(of:with:)`, `CharacterSet.whitespacesAndNewlines`).

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-22-thinking-block.md`
- Sibling files for style: `llm-visualizer/Views/PromptSendButtonStyle.swift`, `llm-visualizer/Models/Message.swift`
- Sibling tests for style: `llm-visualizerTests/MessageTests.swift`, `llm-visualizerTests/ChatViewModelGenerateTests.swift`

---

## Task 1: `ThinkingParser` — TDD

**Files:**
- Create: `llm-visualizer/Models/ThinkingParser.swift`
- Create: `llm-visualizerTests/ThinkingParserTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `llm-visualizerTests/ThinkingParserTests.swift`:

```swift
//
//  ThinkingParserTests.swift
//

import Testing
@testable import llm_visualizer

struct ThinkingParserTests {

    @Test func completeThinkBlock() {
        let result = ThinkingParser.parse("<think>思考内容\n\n答案内容")
        #expect(result.thinking == "思考内容")
        #expect(result.answer == "答案内容")
    }

    @Test func incompleteStream() {
        let result = ThinkingParser.parse("<think>正在思考")
        #expect(result.thinking == "正在思考")
        #expect(result.answer.isEmpty)
    }

    @Test func noThinkTag() {
        let result = ThinkingParser.parse("直接是答案")
        #expect(result.thinking == nil)
        #expect(result.answer == "直接是答案")
    }

    @Test func emptyThinking() {
        let result = ThinkingParser.parse("<think>\n\n只有答案")
        #expect(result.thinking == nil)
        #expect(result.answer == "只有答案")
    }

    @Test func whitespaceTrimmed() {
        let result = ThinkingParser.parse("<think>  \n  思考  \n\n  答案  ")
        #expect(result.thinking == "思考")
        #expect(result.answer == "答案")
    }

    @Test func multilineThinking() {
        let result = ThinkingParser.parse(
            "<think>第一行\n第二行\n\nanswer here"
        )
        #expect(result.thinking == "第一行\n第二行")
        #expect(result.answer == "answer here")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** TEST BUILD FAILED **` with "Cannot find 'ThinkingParser' in scope" (or similar).

- [ ] **Step 3: Implement `ThinkingParser`**

Create `llm-visualizer/Models/ThinkingParser.swift`:

```swift
//
//  ThinkingParser.swift
//

import Foundation

enum ThinkingParser {
    static func parse(_ raw: String) -> (thinking: String?, answer: String) {
        if let endRange = raw.range(of: "") {
            let before = raw[..<endRange.lowerBound]
            let after  = raw[endRange.upperBound...]
            let thinking = before
                .replacingOccurrences(of: "<think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = after.trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking.isEmpty ? nil : thinking, answer)
        }
        if raw.contains("<think>") {
            let thinking = raw
                .replacingOccurrences(of: "<think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking.isEmpty ? nil : thinking, "")
        }
        return (nil, raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
```

- [ ] **Step 4: Build the tests**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'platform=iOS Simulator,name=iPhone 15' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` with `ThinkingParserTests` reporting 6 tests passed.

If the simulator boot takes too long or no simulator is available, run `build-for-testing` instead:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
Expected: `** TEST BUILD SUCCEEDED **` (this confirms the test file compiles against the new `ThinkingParser`, but doesn't run the tests). Then run the test command separately if a simulator is available.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Models/ThinkingParser.swift \
        llm-visualizerTests/ThinkingParserTests.swift
git commit -m "feat(Models): ThinkingParser for <think>…</think> extraction"
```

---

## Task 2: `ThinkingBlock` view component

**Files:**
- Create: `llm-visualizer/Views/ThinkingBlock.swift`

No unit test — the component is purely visual; verified manually in Task 4.

- [ ] **Step 1: Create the file**

Create `llm-visualizer/Views/ThinkingBlock.swift`:

```swift
//
//  ThinkingBlock.swift
//

import SwiftUI

struct ThinkingBlock: View {
    let content: String
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                    Text("Thinking")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            Color(.secondarySystemBackground),
            in: .rect(cornerRadius: 12)
        )
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

If the build fails because Xcode can't find `ThinkingBlock` in scope, the new file is not yet picked up by the project's synchronized folder. Open `llm-visualizer.xcodeproj` in Xcode, drag the file from Finder into the `Views` group in the project navigator, then re-run the build. (In practice this auto-discovery has worked in previous tasks; the fallback is only needed if Xcode hasn't indexed the new file yet.)

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/ThinkingBlock.swift
git commit -m "feat(Views): ThinkingBlock collapsible card"
```

---

## Task 3: Wire `MessageView` `.assistant` branch

**Files:**
- Modify: `llm-visualizer/Views/MessageView.swift`

No new unit test — the change is purely visual; verified manually in Task 4.

- [ ] **Step 1: Read the current `MessageView.swift`**

Read `/Users/africamonkey/work/llm-visualizer/llm-visualizer/Views/MessageView.swift` to confirm the current state (it should still match the post-redesign version with `userBubbleColor`).

- [ ] **Step 2: Replace the `.assistant` branch**

In `llm-visualizer/Views/MessageView.swift`, find the `.assistant` branch:

```swift
        case .assistant:
            HStack {
                Text(LocalizedStringKey(message.content))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
                    .textSelection(.enabled)
                Spacer()
            }
```

Replace it with:

```swift
        case .assistant:
            let parsed = ThinkingParser.parse(message.content)
            VStack(alignment: .leading, spacing: 8) {
                if let thinking = parsed.thinking {
                    ThinkingBlock(content: thinking)
                }
                if !parsed.answer.isEmpty {
                    Text(LocalizedStringKey(parsed.answer))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Color(.secondarySystemBackground),
                            in: .rect(cornerRadius: 16)
                        )
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
```

Leave the `.user` and `.system` branches untouched.

- [ ] **Step 3: Build to verify**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run unit tests to confirm no regression**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'platform=iOS Simulator,name=iPhone 15' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

Expected:
- `ThinkingParserTests` — 6 tests pass (Task 1)
- `MessageTests` — 5 tests pass (existing, unaffected)
- Other tests — skipped (device-only) or pass

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Views/MessageView.swift
git commit -m "feat(Views): split assistant message into ThinkingBlock + answer bubble"
```

---

## Task 4: Manual end-to-end verification

**Files:** none (manual check only)

This is a checklist to confirm the rendering matches the spec on a running simulator. No commit.

- [ ] **Step 1: Cold launch on simulator**

Run on iPhone 15 (iOS 17+) simulator. Open `llm-visualizer.xcodeproj`, select the `llm-visualizer` scheme, destination iPhone 15 simulator, Cmd-R.

Expected:
1. App launches, model loads, status bar shows green dot + "Ready"
2. The conversation area shows the existing system message

- [ ] **Step 2: Send a prompt that does NOT trigger thinking**

Send a simple greeting: type "hi" → tap send.

Expected: a single gray answer bubble appears with the model's response. No ThinkingBlock is rendered above it (the response contains no `<think>` tag).

- [ ] **Step 3: Send a prompt that DOES trigger thinking**

Send a reasoning-style prompt such as "用三步解释为什么天空是蓝色的" (something that elicits a thinking block from Qwen3).

Expected:
1. A ThinkingBlock appears at the top of the assistant message with `🧠 Thinking` header and a chevron-down icon
2. The thinking text streams in token-by-token
3. Once `</think>` arrives, the thinking text freezes
4. An answer bubble appears below the ThinkingBlock and the model's reply streams in

- [ ] **Step 4: Verify collapse / expand**

Tap the ThinkingBlock header.

Expected:
- The body of the ThinkingBlock collapses (fade + slight slide-from-top animation over ~0.2s)
- The chevron rotates from down to right (counterclockwise 90°)
- The answer bubble stays put below

Tap again to expand.

Expected: body slides back in, chevron rotates back to down.

- [ ] **Step 5: Dark mode check**

In Simulator → Features → Toggle Appearance → Dark.

Expected:
- ThinkingBlock background is dark gray (auto from `Color(.secondarySystemBackground)`)
- "Thinking" text and brain icon are still visible (auto from `.foregroundStyle(.secondary)`)
- Answer bubble matches
- Streaming text inside the ThinkingBlock remains readable

- [ ] **Step 6: Long thinking content**

Send a prompt that produces a long thinking block (>20 lines).

Expected:
- The ThinkingBlock grows vertically to fit the content
- The conversation area scrolls naturally to keep the latest message visible
- The ThinkingBlock does not overflow off-screen or get clipped

- [ ] **Step 7: Confirm Cancel / Reset still work**

While the assistant is generating, tap Stop in the status bar.

Expected: `[Cancelled]` is appended to the answer bubble (not the ThinkingBlock). The ThinkingBlock is frozen in its current state.

After at least one full turn, tap the trash icon to reset.

Expected: all messages clear, only the system message remains.

---

## Self-Review Checklist

After executing all tasks, verify:

- [ ] **Spec coverage:**
  - ThinkingBlock header (`brain` SF Symbol, "Thinking" text, chevron): Task 2 §5.1
  - Default expanded (`isExpanded: Bool = true`): Task 2 §5.1
  - Collapse animation (`.easeInOut(duration: 0.2)` + combined transition): Task 2 §5.1
  - Body font (`.caption`), color (`.secondary`), line spacing 2: Task 2 §5.1
  - Container `Color(.secondarySystemBackground)`, corner radius 12: Task 2 §5.1
  - Parser handles complete / incomplete / no-tag / empty / whitespace / multiline cases: Task 1 §8 tests
  - MessageView calls `ThinkingParser.parse(message.content)`: Task 3 §5.3
  - MessageView renders ThinkingBlock when `thinking` is non-nil, answer bubble when `answer` non-empty: Task 3 §5.3
  - `.user` and `.system` branches untouched: Task 3 §5.3
  - Dark mode auto-adapts: Task 2 uses semantic colors; verified in Task 4 step 5
  - Existing unit tests (`MessageTests`, `ChatViewModelGenerateTests`, etc.) still pass: Task 3 §4

- [ ] **TDD discipline:** Task 1 wrote failing tests before implementation.

- [ ] **Commit cadence:** 3 commits (Tasks 1–3), 0 commits for Task 4 (manual only). Matches the spec §11 rollout plan.

- [ ] **No pbxproj edits expected** — Xcode's synchronized folders should auto-pick-up the new files. If `Cmd-B` reports a scope error, drag the file into the project navigator as Task 2 §2 describes.

- [ ] **Manual checklist all green** (Task 4).

- [ ] **No regressions:** all existing unit tests still pass.
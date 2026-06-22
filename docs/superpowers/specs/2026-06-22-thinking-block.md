# Thinking Block Rendering

**Date:** 2026-06-22
**Status:** Approved
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+
**Scope:** Render assistant messages that contain `<think>...</think>` tags as a collapsible thinking block followed by the actual answer bubble.

## 1. Goal

The bundled Qwen3-0.6B model (and most modern reasoning-capable LLMs) may emit
a `<think>...</think>` block before the visible reply. Currently this is
dumped as raw text inside the assistant's gray bubble, mixing reasoning and
answer in an unreadable way. This spec splits the two visually: the thinking
content gets its own collapsible card above the answer bubble.

## 2. Scope

**In scope:**
- New `Views/ThinkingBlock.swift` — collapsible card component
- Modify `Views/MessageView.swift` — parse `<think>` tags inside the
  `.assistant` branch and render ThinkingBlock + answer bubble
- New `llm-visualizerTests/ThinkingParserTests.swift` — unit tests for the
  pure parse function

**Out of scope:**
- Other tags like `<tool_call>` — only `<think>` is recognized
- Markdown / syntax highlighting inside thinking content — plain text only
- Persisting the expanded/collapsed state across app launches — always
  default-expanded
- Changing `Message` struct, `ChatViewModel`, or the streaming code path —
  this is a render-layer change only
- Copy-all or other affordances on the thinking card
- Animations on streaming token updates (intentionally instant — animated
  per-token would stutter)

## 3. Visual Design

### 3.1 ThinkingBlock

```
┌──────────────────────────────────────┐
│ 🧠  Thinking                     ▾   │   ← header (tappable)
├──────────────────────────────────────┤
│ 思考内容…                              │   ← body (when expanded)
│ 逐字逐句                               │
│ …                                     │
└──────────────────────────────────────┘
```

| Element | Value |
|---|---|
| Header icon | SF Symbol `brain` (single-color, tints with `.secondary`) |
| Header label | `Thinking` |
| Chevron | `chevron.down`, rotated -90° when collapsed |
| Container bg | `Color(.secondarySystemBackground)` (auto light/dark) |
| Corner radius | 12 |
| Header padding | H:12, V:8 |
| Body padding | H:12, bottom:10 |
| Body font | `.caption` (12pt) |
| Body color | `.foregroundStyle(.secondary)` |
| Body line spacing | 2pt |
| Max width | `.infinity` (matches answer bubble width) |
| Text selection | Disabled (thinking is not for copying) |

### 3.2 Assistant message composition

When `<think>...</think>` is present:

```
┌─ ThinkingBlock ──────┐
│ 思考内容               │
└──────────────────────┘

┌─── answer bubble ────┐
│ 你好！有什么可以…       │
└──────────────────────┘
```

When `<think>` is absent:

```
┌─── answer bubble ────┐
│ 你好！有什么可以…       │
└──────────────────────┘
```

(Direct fallback — same bubble as the current implementation.)

When the response is mid-stream and `</think>` has not yet appeared: only the
ThinkingBlock is visible (answer is empty); as the model emits more
`<think>` content, the body grows.

### 3.3 Animation

- Tap header → `withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }`
- Body fades + slides slightly from top: `.transition(.opacity.combined(with: .move(edge: .top)))`
- Chevron rotates with the same animation
- Streaming text updates: no per-token animation (would stutter). SwiftUI
  default behavior — text replaces instantly.

### 3.4 Dark mode

All colors are semantic (`.secondarySystemBackground`, `.secondary`), so
dark mode works without explicit handling. Verified manually.

## 4. Files

### 4.1 To create
- `llm-visualizer/Views/ThinkingBlock.swift`
- `llm-visualizerTests/ThinkingParserTests.swift`

### 4.2 To modify
- `llm-visualizer/Views/MessageView.swift` — `.assistant` case rewritten;
  add private `parseAssistant(_:)` helper

No `project.pbxproj` changes expected (Xcode synchronized folders auto-pick
new `.swift` files).

## 5. Component Design

### 5.1 `ThinkingBlock`

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

**Design notes:**
- `isExpanded` defaults to `true` (spec §6 decision)
- `@State` is per-instance, so each ThinkingBlock has its own collapse state
- `.contentShape(Rectangle())` on the header makes the entire row tappable,
  not just the icon/text (default Button hit area is tight)
- `transition` is applied inside `if isExpanded { }` — the modifier is
  visible to SwiftUI when the view enters/exits the tree

### 5.2 `MessageView.parseAssistant(_:)`

```swift
private func parseAssistant(_ raw: String) -> (thinking: String?, answer: String) {
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
```

**Parsing rules (in priority order):**
1. If `</think>` exists: split at its position. Everything before (minus
   the `<think>` tag) becomes `thinking`; everything after becomes
   `answer`. If the thinking portion is empty after trimming, drop it
   (treat as no thinking).
2. If only `<think>` exists (stream not yet ended): everything after the
   tag is `thinking`; `answer` is empty. Same empty-trim rule.
3. If neither tag exists: `thinking` is nil, `answer` is the whole string.

**Edge cases handled:**
- Empty thinking (just `<think>\n\n...`): treated as no thinking
- Whitespace trimming around both halves
- Non-greedy: `String.range(of:)` finds the first `</think>`, which is the
  correct behavior for well-formed output

**Not handled (out of scope):**
- Nested `<think>` tags (model shouldn't emit these)
- Other tags like `<tool_call>` (treated as plain text in answer)
- Escaped versions of the tags (model shouldn't emit these)

### 5.3 `MessageView` `.assistant` branch

```swift
case .assistant:
    let parsed = parseAssistant(message.content)
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

**Notes:**
- Wraps in `VStack(alignment: .leading, spacing: 8)` so ThinkingBlock and
  the answer bubble stack vertically, left-aligned, with 8pt gap
- The outer `.frame(maxWidth: .infinity, alignment: .leading)` makes the
  whole stack left-aligned in the conversation column (previously this
  was done with `HStack { ... Spacer() }`)
- Text selection on the answer is preserved (matches current behavior)
- The `if !parsed.answer.isEmpty` guard hides the answer bubble during the
  pure-thinking phase of streaming (when answer is empty)

**Unchanged branches:**
- `.user` case: no change
- `.system` case: no change

## 6. State Interactions

| UI element | Mid-thinking (stream) | Thinking done | No thinking |
|---|---|---|---|
| ThinkingBlock visible | yes, expanding | yes, frozen | hidden |
| ThinkingBlock expanded | yes (default) | yes (default) | n/a |
| Answer bubble visible | no (empty) | yes, expanding | yes, all text |

The default-expanded state is per-message and persists for the lifetime of
that message view (until the message is removed). It is not preserved across
app launches or chat resets.

## 7. Edge Cases

| Input | Behavior |
|---|---|
| `<think>A\n\nB` | thinking=`A`, answer=`B` |
| `<think>A` (mid-stream) | thinking=`A`, answer empty |
| `B` (no tags) | thinking=nil, answer=`B` |
| `<think>\n\nB` (empty thinking) | thinking=nil, answer=`B` |
| `<think>A<think>B` (nested tags) | thinking=`A` (first match wins), answer=`B` (after first `</think>`) |
| Very long thinking (>50 lines) | ThinkingBlock grows vertically, scrolls naturally inside `ConversationView`'s ScrollView |
| Model emits `[Cancelled]` / `[Error: ...]` after `` | Appended to the answer bubble (matches current behavior — handled in `ChatViewModel.generate()`, not here) |

## 8. Testing

### Unit (`llm-visualizerTests/ThinkingParserTests.swift`)

```swift
//
//  ThinkingParserTests.swift
//

import Testing
@testable import llm_visualizer

@Suite struct ThinkingParserTests {

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

**Note on naming:** The tests reference `ThinkingParser.parse(...)`. The
implementation lives as a private static method on `MessageView` (see
§5.2). To make it testable, we either:
- (A) Make `parseAssistant` an `internal static` on `MessageView` and
  rename to `ThinkingParser.parse` via typealias, OR
- (B) Extract `parseAssistant` into a separate `enum ThinkingParser` in
  its own file.

We choose **(B)** — a new `ThinkingParser.swift` in the Views folder
(matches the pattern of other small focused files like
`PromptSendButtonStyle.swift`). The unit tests then target the public
`ThinkingParser.parse(_:)` directly. `MessageView.assistant` calls
`ThinkingParser.parse(message.content)`.

### UI

No new UI tests — the existing `testEmptyState` and
`testSendButtonIsInitiallyDisabled` don't exercise message rendering, and
`testSendAndReceive` is device-only.

### Manual

1. Send a short prompt ("hi") → single gray bubble, no ThinkingBlock
2. Send a longer prompt that triggers thinking → ThinkingBlock appears
   with text streaming in, then answer bubble starts below it
3. Tap ThinkingBlock header → block collapses, chevron flips, answer
   bubble stays put
4. Tap again → block expands
5. Switch to dark mode → all colors look right, brain symbol + chevron
   are visible
6. App cold-launch with existing conversation that has thinking messages
   → all ThinkingBlocks default to expanded

## 9. Out of Scope (this slice)

- Other reasoning tags (`<tool_call>`, `<reflection>`, etc.)
- Markdown rendering inside thinking
- Persisted collapse state
- "Copy all" or other affordances on the thinking card
- Animated per-token text in the thinking block
- A separate settings toggle to globally collapse thinking

## 10. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Parsing happens on every SwiftUI re-render during streaming | String scan is O(n) and the content is small (KB range) — negligible CPU. If profiling shows a problem, cache via `@State`. |
| ThinkingBlock height grows unbounded for very long thinking | `ConversationView` is a `ScrollView`; long ThinkingBlocks scroll naturally. No truncation (YAGNI). |
| `parseAssistant` could be tested via `MessageView` if private | Spec §8 explicitly extracts `ThinkingParser` into a separate file to enable unit testing — known and accepted. |
| Model output without closing `</think>` looks like the "thinking" phase forever | Stream ends → user sees the ThinkingBlock with no answer. If this happens in practice, fall back to showing the raw content as the answer (covered by edge case 2 in §7, but currently the answer stays empty). |

## 11. Rollout

1. `ThinkingParser.swift` (new, ~25 lines)
2. `ThinkingBlock.swift` (new, ~40 lines)
3. `MessageView.swift` (modify — `.assistant` branch + delegate parsing)
4. `ThinkingParserTests.swift` (new, ~50 lines)

Four commits, one per file. Order matters: parser must exist before
MessageView calls it.
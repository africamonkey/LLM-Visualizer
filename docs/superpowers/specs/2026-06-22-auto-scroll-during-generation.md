# Auto-Scroll During Generation

**Date:** 2026-06-22
**Status:** Approved
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+
**Scope:** Auto-scroll the conversation to the bottom when the assistant streams new content, while respecting the user's manual scroll position.

## 1. Goal

Today the conversation scrolls only via `.defaultScrollAnchor(.bottom)` (sets the initial position). When the assistant streams a long reply, the user has to manually scroll down to follow. This spec adds smart auto-follow: stay locked to the bottom while the user is reading at the bottom, but don't fight them if they scroll up to read history. Provide a small button to jump back to the latest when they've wandered.

## 2. Scope

**In scope:**
- New `Views/JumpToBottomButton.swift` — small circular button shown when
  the user is not at the bottom
- Modify `Views/ConversationView.swift` — add `ScrollViewReader`,
  `@State isAtBottom`, `.onChange` triggers, and the button overlay

**Out of scope:**
- Unread-message badge / counter (no "N new messages" indicator)
- Long-press context menu on messages
- Custom scroll deceleration curves
- Keyboard-avoidance for the input bar (already handled by SwiftUI defaults)
- Changes to Reset / Stop / Cancel behavior

## 3. Behavior

### 3.1 State machine

`@State private var isAtBottom: Bool = true` in `ConversationView`.

| Event | Action | `isAtBottom` after |
|---|---|---|
| Cold launch (1 system message) | `.defaultScrollAnchor(.bottom)` → already at bottom | `true` |
| User sends a message (`messages.count` ↑) | Force scroll to new last message | `true` |
| Assistant streams new token (`messages.last?.content` grows) | If `isAtBottom` → scroll to last; else stay put | unchanged |
| User scrolls up — last message leaves viewport | — | `false` |
| User scrolls down — last message re-enters viewport | — | `true` |
| User taps jump-to-bottom button | Scroll to last + bounce effect | `true` |
| User taps Stop / presses Reset | Existing behavior unchanged | unchanged |

### 3.2 Animation

- **Follow during streaming**: `withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(...) }`
  - 100ms linear keeps the scroll smooth but tight to the token rate (~23 t/s);
    no jank, no overshoot
- **Jump-to-bottom tap**: `withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(...) }`
  - Slightly slower, more deliberate feel for a user-initiated action
- **Button appear / disappear**: `.transition(.scale.combined(with: .opacity))`
- **Bounce on tap**: `.symbolEffect(.bounce, value: tapCounter)` (iOS 17 SF Symbol bounce)

### 3.3 Jump-to-bottom button

| Property | Value |
|---|---|
| Shape | Circle, 36×36pt |
| Background | `Color.accentColor` (system tint) |
| Icon | SF Symbol `arrow.down`, white, `.system(size: 16, weight: .semibold)` |
| Border | 0.5pt `Color(.separator)` (visible edge in both light and dark mode) |
| Shadow | `shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)` |
| Position | Bottom-right of `ConversationView`, 16pt from bottom, 12pt from right |
| Visibility | Parent controls via `if isAtBottom { } else { JumpToBottomButton(...) }` |
| Tap action | Scroll to bottom + set `isAtBottom = true` + trigger bounce |

**Position diagram:**
```
┌─────────────────────────┐
│                         │
│  ← chat messages         │
│                         │
│                         │
│                    ┌──┐ │
│                    │↓ │ │  ← jump button (only when !isAtBottom)
│                    └──┘ │
├─────────────────────────┤
│ [input]    [send]       │  ← input bar (not affected)
└─────────────────────────┘
```

## 4. Files

### 4.1 To create
- `llm-visualizer/Views/JumpToBottomButton.swift`

### 4.2 To modify
- `llm-visualizer/Views/ConversationView.swift`

No `project.pbxproj` changes expected (Xcode synchronized folders auto-pick
new `.swift` files).

## 5. Component Design

### 5.1 `JumpToBottomButton`

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

**Design notes:**
- Pure presentational — receives the `action` callback from the parent;
  no internal scroll logic. Keeps the view composable and testable.
- `.symbolEffect(.bounce, value: tapCounter)` is iOS 17+; the `tapCounter`
  is a `Hashable` value the modifier watches for changes.
- The button is always rendered; the parent (ConversationView) decides
  whether to show it via `if isAtBottom { EmptyView() } else { ... }`.
  This keeps the transition animation clean (the view enters/exits the
  view tree, triggering `.transition`).

### 5.2 `ConversationView` (rewritten body)

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

**Design notes:**
- `ScrollViewReader` wraps the whole layout; the `proxy` is captured by
  the closures for `.onChange` and the jump button
- `ZStack(alignment: .bottomTrailing)` overlays the jump button on the
  bottom-right of the conversation area
- `.id(message.id)` on each `MessageView` is what `proxy.scrollTo(...)`
  targets. `Message.id` is already a `UUID` (Identifiable conformance)
- `.onAppear` / `.onDisappear` on the last message track viewport
  membership. SwiftUI fires `.onAppear` when the view becomes visible
  and `.onDisappear` when it leaves. This is the cleanest iOS 17 way to
  detect "user has scrolled away from the bottom" without GeometryReader
- Two `.onChange` handlers split responsibility:
  - `count` change → user-initiated new message → force scroll
  - `content` change → assistant streaming → conditional scroll
- `.defaultScrollAnchor(.bottom)` is kept as a fallback for the very
  first render (before any `.onAppear` fires)
- The jump button's `if !isAtBottom { ... }` is inside the ZStack so the
  `.transition` is visible to SwiftUI when the view enters/exits the
  view tree

## 6. Edge Cases

| Scenario | Behavior |
|---|---|
| Cold launch (1 system message) | `.defaultScrollAnchor(.bottom)` keeps at bottom, `isAtBottom = true`, no button |
| Very short conversation (< 1 screen) | No scrollable area; jump button never appears; behavior is correct |
| Very long conversation (> 10 screens) | `scrollTo` is O(1) lookup by ID, no perf concern |
| User sends message mid-stream (defensive — button is disabled but…) | `messages.count` ↑ triggers force scroll, the new state takes over |
| Assistant streams after user has scrolled up | `isAtBottom == false` → no scroll, button remains visible |
| User scrolls back to bottom during streaming | `.onAppear` of last message → `isAtBottom = true` → auto-resume follow |
| User taps Stop during streaming | `[Cancelled]` appended; `isAtBottom` state preserved; scroll behavior follows existing rules |
| User taps Reset | `messages` becomes `[.system("…")]`; `messages.count` changes from N to 1; the `.onChange(count)` handler force-scrolls to the system message; `isAtBottom` stays `true` |
| Keyboard appears while at bottom | SwiftUI default keyboard avoidance shifts the input bar; the conversation's auto-follow keeps the bottom in view |

## 7. Testing

### Unit
No new unit tests — scroll behavior is SwiftUI-only; the underlying logic
(`isAtBottom` flip) is too tightly coupled with SwiftUI's lifecycle to
test in isolation.

### UI (`llm-visualizerUITests/`)
No new UI tests — the existing device-only `testSendAndReceive` indirectly
exercises the auto-scroll path, but asserting specific scroll positions in
XCTest is brittle and adds little value.

### Manual (simulator)
1. Cold launch → conversation at bottom, no jump button
2. Send "hi" → auto-scrolls to the new message, no button
3. Assistant starts streaming → continuously follows the bottom
4. While streaming, manually scroll up → scroll stops following, jump
   button appears
5. Manually scroll back down to the last message → jump button
   disappears, auto-follow resumes
6. Tap the jump button (after scrolling up) → scrolls to bottom with
   bounce animation, button disappears
7. Tap Stop mid-stream → `[Cancelled]` appended, scroll state preserved
8. Tap Reset → conversation clears, no jump button
9. Repeat the cycle several times → state is stable, no leaks
10. Toggle dark mode → button colors / shadow / border all read correctly

## 8. Out of Scope (this slice)

- Unread-message badge / "N new messages" indicator
- Long-press menu on messages
- Custom scroll deceleration
- "Scroll to top" button
- "Scroll to a specific message" deep-linking
- Persisted scroll position across app launches
- Animated "scroll indicator" (the native iOS scroll bar)

## 9. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `.onAppear` / `.onDisappear` on LazyVStack children may fire during initial render even when off-screen | iOS 17 SwiftUI only fires `.onAppear` when the view is actually in the viewport. With `LazyVStack`, the last message is only created/rendered when it nears the visible area, so this works correctly in practice. If false-positives appear in testing, add a debounce via `Task { try? await Task.sleep(for: .milliseconds(50)); ... }` before setting `isAtBottom`. |
| Many `.onChange` calls per second during streaming | SwiftUI coalesces state updates; `scrollTo` is O(1). Token rate (~23 t/s) is well within SwiftUI's capacity. |
| `messages.last?.content` change fires for messages that are not actually at the bottom (e.g. after Reset) | The `guard isAtBottom` check prevents scrolling in this case. |
| `.symbolEffect(.bounce, value: tapCounter)` requires iOS 17; project targets 17.0+ | Confirmed by spec. |
| Jump button blocks taps to messages behind it | The button is 36pt; placed in the bottom-right; messages there are sparse (typically the trailing edge of the last assistant message). Acceptable for a small "utility" button. |
| `ScrollViewReader` requires the wrapped view to have a non-zero size | The `ZStack` inside fills the parent (`ChatView` gives the conversation area the available space between the navigation bar and the input bar). |

## 10. Rollout

1. `JumpToBottomButton.swift` (new, ~28 lines)
2. `ConversationView.swift` (modify — wrap in `ScrollViewReader` + ZStack,
   add `@State`, `.onChange`, `.onAppear`/`.onDisappear`, button overlay)

Two commits, one per file. Order: button first (so it exists when
`ConversationView` references it).
# Prompt Field Redesign + StatusBar Status LED

**Date:** 2026-06-22
**Status:** Approved
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+
**Scope:** Visual polish of the bottom-of-chat area — replace the generic
`PromptField` look with a ChatGPT-like rounded-rect + external blue square
button, and add a colored status LED to `StatusBar`.

## 1. Goal

The current `PromptField` (`.roundedBorder` `TextField` + `.borderedProminent`
paperplane button) looks generic and dated for an LLM tool. The current
`StatusBar` has no visual cue of model state beyond text. This spec:

1. Replaces the input bar visuals with a modern AI-tool aesthetic that fits
   the project's "premium local LLM tool" positioning.
2. Adds a colored status LED to `StatusBar` so the user can see model state
   at a glance, even when the status text is short or truncated.

## 2. Scope

**In scope:**
- New `PromptSendButtonStyle: ButtonStyle`
- New `PromptFieldBackground: ViewModifier`
- Rewrite of `Views/PromptField.swift` to use the two new primitives
- One-line adjustment of `Views/ChatView.swift` padding around `PromptField`
- LED dot + pulse animation added to `Views/StatusBar.swift`

**Out of scope:**
- Any change to `ChatViewModel` (behavior, state, generation flow)
- Any change to message rendering
- Attachment / voice / camera buttons (text-only spec)
- Input history navigation (up/down arrows)
- Customization of LED colors
- macOS support

## 3. Visual Design

### 3.1 PromptField layout

```
┌──────────────────────────────────────────┐  ┌──────┐
│  Ask anything…                          │  │  ↑   │
└──────────────────────────────────────────┘  └──────┘
   ↑ rounded-rect text field (white bg,         ↑ 40×40 square blue button
     0.5px separator border, radius 12,         (radius 12, system tint)
     padding 8/12, min height 40pt)
```

- Horizontal gap between field and button: 8pt
- Text field appearance (light mode): white background, `Color(.separator)`
  stroke (0.5pt), corner radius 12
- Text field appearance (dark mode): same white background (we keep the
  field white to maintain contrast with the button and messages); the
  separator stroke and label colors automatically adapt via the system
  semantic color
- Button: 40×40pt, `Color.accentColor` solid fill, SF Symbol `arrow.up`
  in white at 16pt semibold
- Pressed state: button background at 70% opacity (via
  `configuration.isPressed`)
- Disabled state: button at 35% opacity (still blue, not gray) — handled
  automatically by the SwiftUI environment value `\.isEnabled`

### 3.2 StatusBar LED

A 9pt circular dot sits immediately to the left of the status text in every
`ModelState` branch. Colors:

| State | Color | Symbol | Animation |
|---|---|---|---|
| `.idle` | `Color.gray` (system secondary) | static dot | none |
| `.loading` | `Color.orange` | static dot | 1.2s ease-in-out opacity pulse (1.0 ↔ 0.45) |
| `.loaded` + `!isGenerating` | `Color.green` | static dot | none |
| `.loaded` + `isGenerating` | `Color.accentColor` | static dot | none |
| `.error` | `Color.red` | static dot | none |

LED has a 0.5pt inset shadow (`rgba(0,0,0,0.08)`) for subtle depth.

## 4. Files

### 4.1 To create
- `llm-visualizer/Views/PromptSendButtonStyle.swift`
- `llm-visualizer/Views/PromptFieldBackground.swift`

### 4.2 To modify
- `llm-visualizer/Views/PromptField.swift` (full rewrite — same public API)
- `llm-visualizer/Views/ChatView.swift` (one-line padding adjustment)
- `llm-visualizer/Views/StatusBar.swift` (add `statusDot(...)` helper +
  prepend to each status text branch)

No pbxproj changes expected — these are all Swift files in an existing
group; Xcode auto-syncs new files added to the folder. If pbxproj does need
a refresh, the engineer will see it as an unadded file in the project
navigator.

## 5. Component Design

### 5.1 `PromptSendButtonStyle`

```swift
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

**Design notes:**
- `@Environment(\.isEnabled)` is read inside `makeBody` — SwiftUI injects the
  current environment value when the button is used inside `.disabled(...)`,
  so no caller-side opacity math is needed
- `configuration.isPressed` adds tactile feedback without changing shape
- Public `color` parameter allows future reuse but defaults to `.accentColor`
- The opacity layering is: pressed multiplies down from the base color,
  disabled multiplies the whole button down to 0.35 — these compose
  naturally (pressing a disabled button stays at 0.35 × 0.7 = ~0.25, but
  disabled views don't normally respond to press anyway)

### 5.2 `PromptFieldBackground`

```swift
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

**Design notes:**
- White background is intentional even in dark mode — the button and
  surrounding UI keep strong contrast; using a darker bg would make the
  field visually merge with the message area
- `Color(.separator)` is a UIKit-bridged semantic color that resolves to
  the right value in light/dark mode automatically
- `minHeight: 40` ensures the field is tall enough for one line of body
  text plus the vertical padding

### 5.3 `PromptField` (rewritten)

Same public API as before:
```swift
struct PromptField: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let canSend: Bool
    let onSend: () -> Void
    // body uses PromptFieldBackground and PromptSendButtonStyle
}
```

Body composition:
```
HStack(spacing: 8) {
    TextField("Ask anything…", text: $prompt, axis: .vertical)
        .lineLimit(1...4)
        .submitLabel(.send)
        .onSubmit { if canSend { onSend() } }
        .modifier(PromptFieldBackground())

    Button(action: onSend) {
        Image(systemName: "arrow.up")
    }
    .buttonStyle(PromptSendButtonStyle())
    .disabled(!canSend)
    .keyboardShortcut(.return, modifiers: [])
}
```

`keyboardShortcut(.return, modifiers: [])` is preserved from the original
so a hardware-Return key (iPad keyboard, Mac Catalyst) still triggers send
when the field is focused.

Placeholder text changed from `"Prompt"` to `"Ask anything…"` to match the
new AI-tool tone. (This is a copy change only; it does not affect
behavior.)

### 5.4 `ChatView` (one-line change)

Replace:
```swift
PromptField(...)
    .padding()
```

With:
```swift
PromptField(...)
    .padding(.horizontal, 12)
    .padding(.bottom, 10)
```

Rationale: removes the symmetric `.padding()` which added visual weight
above the input bar; left/right padding of 12pt matches the
`ConversationView`'s horizontal padding so messages and input align; the
bottom padding is reduced from `.padding()`'s default 16pt to 10pt to
keep the bar closer to the safe area.

### 5.5 `StatusBar` — `statusDot` helper

Add a private helper:
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
        .opacity(pulseOn ? 0.45 : 1.0)        // pulse-driven
}
```

State for the pulse animation:
```swift
@State private var pulseOn = false
```

Lifecycle and animation (cleaner than nested `withAnimation` — uses the
`.animation(_:value:)` modifier that supports `nil` to mean "no animation"):
```swift
// Inside the dot's modifier chain:
.opacity(pulseOn ? 0.45 : 1.0)
.animation(
    pulseOn
        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        : nil,
    value: pulseOn
)
.onChange(of: modelState) { _, new in
    pulseOn = (new == .loading)
}
.onAppear {
    pulseOn = (modelState == .loading)
}
```

Behavior:
- When `pulseOn` flips to `true`, the animation modifier activates the
  repeating ease-in-out, oscillating opacity between 1.0 and 0.45 forever.
- When `pulseOn` flips to `false`, the animation becomes `nil`, so the
  opacity snaps to 1.0 with no animation. The repeating animation stops
  immediately (no leaked repeats).
- On state transitions out of `.loading`, the dot returns to its base
  color and full opacity in the same frame.

Each `statusText` branch's content is wrapped in an `HStack(spacing: 6)`
with `statusDot(modelState, isGenerating: isGenerating)` first, then the
existing text content. For example, the `.loaded` + `!isGenerating` branch
becomes:
```swift
HStack(spacing: 6) {
    statusDot(modelState, isGenerating: false)
    Text("Ready").foregroundStyle(.secondary)
}
```

## 6. State Interactions

| UI element | Idle | Loading | Ready | Generating | Error |
|---|---|---|---|---|---|
| TextField | enabled | enabled | enabled | enabled (can draft) | enabled |
| Send button | disabled, faded blue | disabled, faded blue | enabled if prompt non-empty | disabled, faded blue | disabled, faded blue |
| Status dot | gray static | orange pulsing | green static | blue static | red static |
| Status text | "Initializing…" | "Loading model…" | "Ready" | "Generating · X.X t/s" | error msg + Retry |
| Stop button | hidden | hidden | hidden | visible | hidden |

**Can-send logic** (unchanged, lives in `ChatView`):
```swift
canSend = !isGenerating
       && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
       && modelState == .loaded
```

## 7. Dark Mode

- `Color(.separator)` auto-adapts (light: rgba(60,60,67,0.29), dark: rgba(84,84,88,0.65))
- `Color.accentColor` auto-adapts (system blue in both, slight lightness shift in dark)
- System colors `.green`, `.red`, `.orange`, `.gray` all adapt via UIColor bridging
- Text field background stays white in both modes — by design

## 8. Edge Cases

- **Long prompt (>4 lines):** the field caps at 4 lines; content scrolls
  inside the field. Internal `TextEditor` (not used here) handles this
  automatically; `TextField` with `axis: .vertical` and `lineLimit(1...4)`
  also caps visually.
- **Empty prompt after trim:** send button is disabled (faded blue);
  pressing Return does nothing.
- **Send while still loading:** send button is disabled by `modelState != .loaded`
  in the can-send predicate (existing).
- **Pulse animation lifecycle:** when `modelState` transitions away from
  `.loading`, the animation is cancelled by setting `pulseOn = false`
  inside a zero-duration animation block. This prevents the animation
  from continuing on a dot that is now a different color.
- **Focus after send:** the `TextField` keeps focus naturally because
  SwiftUI doesn't move focus when its binding clears; users can send
  multiple messages in succession.

## 9. Testing

### Unit
No new unit tests — visual-only changes, no new behavior.

### UI (`llm-visualizerUITests/`)
- Add `testPromptFieldPlaceholder` — assert the new placeholder
  `"Ask anything…"` is visible after launch
- Add `testSendButtonFadedWhenEmpty` — assert the send button is visible
  but its accessibility state is disabled when the field is empty
- Existing tests (`testEmptyState`, `testStatusBarTransitionsToReady`,
  `testSendAndReceive`) continue to pass with the new visuals (placeholder
  text changes from `"Prompt"` to `"Ask anything…"` — update the
  `"Prompt"` text-field lookup in `testEmptyState` and
  `testSendAndReceive` to match the new placeholder)

### Manual
1. Empty prompt → send button is faded blue, not gray
2. Type text → button becomes solid blue; press Return → sends
3. While generating → button is faded blue; status dot is blue and status
   text reads "Generating · X.X t/s"
4. Cold app launch → status dot starts gray ("Initializing…"), pulses
   orange during "Loading model…", settles green on "Ready"
5. Force an error (e.g. temporarily rename model dir in bundle) → status
   dot is red, Retry button visible
6. Dark mode → field border, button tint, LED colors all read correctly
7. iPad landscape → input bar spans full width with 12pt side padding;
   button stays right-aligned and reachable
8. Long prompt → field grows up to 4 lines then caps

## 10. Out of Scope (this slice)

- Changing the placeholder's dynamic hint (e.g. "Ask Qwen anything…")
- Custom keyboard toolbar / command palette
- Attachment / voice / image input
- Input history (up/down arrows)
- LED color picker
- Animated LED transitions between colors

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| White field looks "wrong" in dark mode | Tested in §9.7; if it reads as too bright, follow-up task can switch to `Color(.secondarySystemBackground)` |
| Pulse animation leaks across state changes | Explicit `pulseOn = false` reset in `.onChange` (§5.5) |
| New files not picked up by pbxproj | Build immediately after adding files; if Xcode doesn't see them, drag into the Views group |
| Placeholder change breaks existing UI tests | Explicitly update the placeholder text in the affected tests (§9) |

## 12. Rollout

Single commit per file (per existing project convention). Order:
1. `PromptSendButtonStyle.swift` (new)
2. `PromptFieldBackground.swift` (new)
3. `PromptField.swift` (rewrite — depends on 1 & 2)
4. `ChatView.swift` (one-line padding)
5. `StatusBar.swift` (LED)
6. `llm-visualizerUITests/llm_visualizerUITests.swift` (test updates)
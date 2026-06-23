# Localization (English + Simplified Chinese)

**Date:** 2026-06-23
**Status:** Approved
**Target:** iOS 17.0+ (iPhone + iPad) + macOS, Swift 5.9+
**Scope:** Add Simplified Chinese (zh-Hans) localization to all user-facing static UI strings, following the system language.

## 1. Goal

The LLM Visualizer app currently has all UI text hardcoded in English. Users
in mainland China (a primary audience for a Qwen3-based app) will see English
status text ("Initializing…", "Loading model…", "Thinking", etc.) on a
Chinese device, which feels unpolished and signals "unfinished product."

This spec adds full Simplified Chinese support for all static UI strings, with
**English as the base language** and the app following the system language
automatically. No in-app language toggle — if the user wants a different
language, they change it in iOS Settings, which is the platform default.

## 2. Scope

**In scope:**
- All user-facing static UI strings (status bar, thinking block header,
  navigation title, button labels)
- One new file: `llm-visualizer/Resources/Localizable.xcstrings` (Xcode
  15+ String Catalog, single source of truth for translations)
- Minor code edit in `StatusBar.swift` for the one formatted string
  (tokens/sec)
- `project.pbxproj` updates: add `zh-Hans` to `knownRegions`, register
  the `.xcstrings` file

**Out of scope:**
- LLM-generated content (model replies, thinking content streamed from the
  model) — these stay in whatever language the model emits
- Error messages from system / MLX / tokenizer — the `[Error: ...]`
  prefix in `ChatViewModel.swift` is not localized (errors are dynamic
  content, technically out of scope by user decision)
- In-app language switcher — system locale only
- Other languages (ja, ko, traditional Chinese, etc.) — not now, but
  the String Catalog structure makes adding them trivial later
- Right-to-left support (not needed for zh/en)
- Localizing the app name (uses `CFBundleDisplayName` from Info.plist;
  follows Xcode's standard localization flow — out of scope for this spec)

## 3. Architecture

### 3.1 Mechanism

Use Apple's **String Catalogs** (`.xcstrings`), introduced in Xcode 15. The
project already sets `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` in
`project.pbxproj` (lines 353, 411), so Xcode is configured to use catalogs
natively.

**How it works at compile time:**

1. SwiftUI source contains `Text("Loading model…")` (a `LocalizedStringKey`).
2. Xcode scans the build, collects all string literals used in
   `LocalizedStringKey` contexts, and matches each against the catalog.
3. At runtime, the system reads `Locale.current` and picks the
   appropriate translation from the catalog. If no translation exists for
   the current language, it falls back to the source language (English).

### 3.2 File layout

```
llm-visualizer/
├── Resources/                       ← new directory
│   └── Localizable.xcstrings        ← new (string catalog)
├── Views/Chat/
│   ├── StatusBar.swift              ← modify (one line)
│   ├── ThinkingBlock.swift          ← no change
│   └── ChatView.swift               ← no change
└── ...
```

`Localizable.xcstrings` is a single JSON file. Structure:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Loading model…" : {
      "comment" : { "defaultValue" : "" },
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Loading model…" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "正在加载模型…" } }
      }
    },
    ...
  },
  "version" : "1.0"
}
```

### 3.3 Why this approach

The project already has `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` and uses
Xcode 16+'s `PBXFileSystemSynchronizedRootGroup` (auto-picks up new files in
`llm-visualizer/`). String Catalogs integrate cleanly with both — no manual
`.strings` files, no per-key `NSLocalizedString` calls, no key naming
convention overhead. Future languages are added by appending a new
localization entry to the same file.

## 4. Strings to Localize

| # | English (source) | 中文 (zh-Hans) | Location | Code path |
|---|---|---|---|---|
| 1 | `LLM Visualizer` | `LLM 可视化` | `ChatView.swift:52` | `.navigationTitle("LLM Visualizer")` |
| 2 | `Initializing…` | `初始化中…` | `StatusBar.swift:52` | `Text("Initializing…")` |
| 3 | `Loading model…` | `正在加载模型…` | `StatusBar.swift:58` | `Text("Loading model…")` |
| 4 | `Ready` | `就绪` | `StatusBar.swift:71` | `Text("Ready")` |
| 5 | `Thinking` | `思考中` | `ThinkingBlock.swift:20` | `Text("Thinking")` |
| 6 | `Stop` | `停止` | `StatusBar.swift:25` | `Label("Stop", systemImage: "stop.circle.fill")` |
| 7 | `Retry` | `重试` | `StatusBar.swift:83` | `Button("Retry", action: onRetry)` |
| 8 | `Generating · %.1f t/s` | `生成中 · %.1f tokens/秒` | `StatusBar.swift:64` | `String(format:)` |

**Translation notes:**
- All strings preserve their original punctuation (`…`, `.`)
- "t/s" → "tokens/秒" — Chinese readers don't use "t/s" abbreviation;
  spelled out for clarity
- "Thinking" → "思考中" — the "中" suffix indicates in-progress, matching
  the visual meaning (the model is currently thinking)
- "Stop" / "Retry" / "Ready" use the standard iOS localized equivalents
- Ellipsis `…` (U+2026) preserved in both languages

## 5. Code Changes

### 5.1 `StatusBar.swift` line 64 — the only required code edit

The `String(format:)` call must be wrapped in `String(localized:)` so the
catalog's locale-specific format rules (e.g. decimal separator) are honored.

**Before:**

```swift
Label(String(format: "Generating · %.1f t/s", tokensPerSecond),
      systemImage: "circle.fill")
    .foregroundStyle(.tint)
```

**After:**

```swift
let format = String(
    localized: "Generating · %.1f t/s",
    defaultValue: "Generating · %.1f t/s"
)
Label(String(format: format, tokensPerSecond),
      systemImage: "circle.fill")
    .foregroundStyle(.tint)
```

`String(localized:defaultValue:)` (iOS 15+) explicitly registers the string
with the catalog and provides a compile-time fallback identical to the
source. This is the recommended pattern for formatted localizable strings.

### 5.2 No changes to other files

- `ChatView.swift`, `ThinkingBlock.swift`, and the other six `Text(...)` /
  `Label(...)` / `Button(...)` calls in `StatusBar.swift` use bare string
  literals, which SwiftUI compiles as `LocalizedStringKey`. Xcode's String
  Catalog extractor automatically picks them up at build time. **No source
  edit needed for those.**

### 5.3 `ChatViewModel.swift` — no changes

The `[Error: \(error.localizedDescription)]` formatting on lines 69 and 108
remains as-is. Per scope decision, dynamic error content is not localized.

## 6. Project File Changes

### 6.1 `llm-visualizer.xcodeproj/project.pbxproj`

**Add to `knownRegions` (currently near line 213):**

```
knownRegions = (
    en,
    Base,
    "zh-Hans",
);
```

**Register the string catalog:**

The project uses `PBXFileSystemSynchronizedRootGroup` for `llm-visualizer/`,
so a new file dropped into `llm-visualizer/Resources/Localizable.xcstrings`
is auto-picked up on the next Xcode open. No explicit `PBXFileReference`
needed **for the file itself**.

However, the `.xcstrings` file needs to be flagged as a known localization
resource. Xcode handles this automatically when the file's contents declare
`sourceLanguage` + `strings` + a `localizations` map. In practice, opening
the project in Xcode after creating the file is enough — Xcode adds the
necessary entries to the project file.

### 6.2 Verify after opening in Xcode

1. Open the project in Xcode 16+
2. Select `Localizable.xcstrings` in the navigator → confirm the file
   inspector shows: **English (Base)**, **Chinese (Simplified) (zh-Hans)**
3. If only "English" shows: click **Localize…** in the file inspector,
   pick English, then click the **+** under Localizations to add
   Chinese (Simplified) — zh-Hans
4. Confirm the build target includes the file (should be automatic via
   the synchronized folder)

## 7. Component Design

### 7.1 The String Catalog file

Hand-authored JSON following Xcode's `.xcstrings` schema. The file is small
enough (~8 keys × 2 languages) that hand-authoring is faster than clicking
through Xcode's UI. The schema is documented in
[Apple's developer docs](https://developer.apple.com/documentation/xcode/localizing-and-asset-catalogs)
and is stable.

Example entry (one of the eight keys):

```json
"Generating · %.1f t/s" : {
  "comment" : "Status bar text while model is generating tokens. %f is the current tokens-per-second throughput, formatted to one decimal place.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Generating · %.1f t/s"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "生成中 · %.1f tokens/秒"
      }
    }
  }
}
```

### 7.2 Comment conventions

Each entry gets a short `comment` describing context — useful for future
translators and for grep-ability. The comment is **not** shown in the
running UI; it's metadata for the catalog.

## 8. State Interactions

Not applicable — localization is a pure compile-time / runtime locale
lookup, no view state involved.

## 9. Edge Cases

| Case | Behavior |
|---|---|
| Device language is English | Source strings shown (no change from today) |
| Device language is Simplified Chinese | `zh-Hans` translations shown |
| Device language is Traditional Chinese, Japanese, etc. | Falls back to source (English) — same as today. Adding more languages is a future task. |
| Device region is mainland China but language is English | Source strings shown — language is the only selector |
| `tokensPerSecond` value when current language is `zh-Hans` | `String(format:)` uses the `%.1f` format spec — both `en` and `zh-Hans` use `.` as the decimal separator (zh-Hans is based on the CJK number format which preserves `.`). Both languages display `12.3` — visually consistent. |
| Missing translation in catalog for one of the 8 keys | Xcode build fails or Xcode warns depending on catalog state. Mitigation: verify all 8 keys are filled before merging. |

## 10. Testing

### Manual verification (primary — no existing UI test infrastructure for this)

1. **English locale (regression):**
   - Set simulator/device to English → confirm all 8 strings match §4 column 2
2. **Simplified Chinese locale (new behavior):**
   - Set simulator/device to 简体中文 → confirm all 8 strings match §4 column 3
3. **Live switch:**
   - In iOS Settings, change language from English to Chinese (or vice versa)
     while the app is running — confirm the UI re-renders with new strings
     on next screen entry (may require app restart depending on iOS version)
4. **Token-rate format string:**
   - In a state where generation is active, confirm the speed number
     (e.g. `12.3`) appears correctly in both languages
5. **No-translation fallback (sanity):**
   - Set device to French → confirm all strings show English (no
     half-translated state)

### Unit tests

None — there's no testable pure function in this change. The existing test
suite (`llm-visualizerTests/`) targets model and view-model logic, not
localized strings. Adding a "does this key exist in catalog" test would
couple the test to the catalog file structure, low value.

### Build verification

- `xcodebuild build` for the iOS scheme must succeed with the new file
- Build must produce a `.appex` / `.app` bundle containing
  `zh-Hans.lproj/Localizable.xcstrings` (or the catalog's compiled
  equivalent) in the resources

## 11. Out of Scope (this slice)

- Other languages (ja, ko, traditional Chinese, etc.) — same file, easy to
  add later
- In-app language picker / manual override
- Localized app name (would require `InfoPlist.strings` + App Store Connect
  setup, separate workflow)
- Localizing error messages (dynamic content, per scope decision)
- Localizing the model name "Qwen3-0.6B-4bit-DWQ-053125" (it's a model
  identifier, not UI text)
- Localizing `fatalError` messages in `LLMService.swift` (developer-facing,
  never shown to users in release)

## 12. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `project.pbxproj` edits break the project (very common with hand edits) | Use Xcode UI to add the file rather than hand-editing pbxproj. The synchronized folder picks up new files automatically. |
| Forgetting to add one of the 8 keys → untranslated string appears in zh-Hans UI | Verification step: open `.xcstrings` in Xcode, ensure 8/8 keys have `zh-Hans` `state: translated` before building. Add to PR checklist. |
| Chinese translation reads awkwardly (e.g. "生成中 · 12.3 tokens/秒" is wordy) | Translation notes in §4. Acceptable as v1; can be tightened later without code changes (catalog edit only). |
| `String(localized:)` on the format string has a different behavior in some edge case | The pattern is documented and recommended by Apple since iOS 15. If issues arise, fall back to `String(format: NSLocalizedString("Generating · %.1f t/s", comment: ""), tokensPerSecond)`. |
| macOS sandbox / bundle resource access issues | String Catalogs are standard resources; macOS and iOS both handle them identically. No additional entitlement needed. |

## 13. Rollout

1. Create `llm-visualizer/Resources/Localizable.xcstrings` (hand-written
   JSON, 8 entries, both languages filled)
2. Open project in Xcode 16+, confirm `Localizable.xcstrings` is recognized
   as a localization resource (English Base + zh-Hans)
3. Modify `StatusBar.swift:64` to use `String(localized:defaultValue:)`
4. Build → confirm no warnings about untranslated strings
5. Manual test in Simulator (English + Chinese)
6. Commit + push

Five concrete steps, one new file, one small code edit, one project file
update (Xcode-handled).

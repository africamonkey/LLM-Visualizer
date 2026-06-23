# Localization (English + Simplified Chinese) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Simplified Chinese (zh-Hans) translations for all 8 user-facing static UI strings, following the system language automatically. English remains the base language.

**Architecture:** Xcode 15+ String Catalog (`Localizable.xcstrings`) — a single JSON file under `llm-visualizer/Resources/` is the source of truth for translations. SwiftUI source stays nearly untouched: bare `Text("…")` / `Label("…")` / `Button("…")` literals are auto-picked up as `LocalizedStringKey`. The single `String(format:)` call is wrapped in `String(localized:defaultValue:)` to register the format string with the catalog. The project file is updated to add `zh-Hans` to `knownRegions`. No in-app language toggle; the system locale drives selection.

**Tech Stack:** Swift 5.9+ / iOS 17.0+, SwiftUI (`LocalizedStringKey`, `String(localized:defaultValue:)`), Xcode 15+ String Catalogs (`.xcstrings`).

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-23-localization-design.md`
- Touched source: `llm-visualizer/Views/Chat/StatusBar.swift`
- Project file: `llm-visualizer.xcodeproj/project.pbxproj`

---

## Task 1: Create the String Catalog

**Files:**
- Create: `llm-visualizer/Resources/Localizable.xcstrings`

No unit test — this is a configuration file; verified at build time and by manual UI check in Task 4.

- [ ] **Step 1: Create the directory**

Run:
```bash
mkdir -p llm-visualizer/Resources
```

Expected: directory exists (no output). Verify with `ls llm-visualizer/Resources` → empty.

- [ ] **Step 2: Create the catalog file**

Create `llm-visualizer/Resources/Localizable.xcstrings` with the following exact content (this is the complete file — 8 keys, English Base + Simplified Chinese):

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Generating · %.1f t/s" : {
      "comment" : "Status bar text while model is generating tokens. The placeholder is the current tokens-per-second throughput, formatted to one decimal place.",
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
    },
    "Initializing…" : {
      "comment" : "Status bar text while the model state is idle (e.g. just after launch, before model starts loading).",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Initializing…"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "初始化中…"
          }
        }
      }
    },
    "LLM Visualizer" : {
      "comment" : "Navigation bar title of the main chat view.",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "LLM Visualizer"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "LLM 可视化"
          }
        }
      }
    },
    "Loading model…" : {
      "comment" : "Status bar text while the model state is loading (model weights being read from disk).",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Loading model…"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "正在加载模型…"
          }
        }
      }
    },
    "Ready" : {
      "comment" : "Status bar text when the model is loaded and idle, waiting for user input.",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ready"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "就绪"
          }
        }
      }
    },
    "Retry" : {
      "comment" : "Button label in the status bar's error state. Tapping it retries the last action.",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Retry"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "重试"
          }
        }
      }
    },
    "Stop" : {
      "comment" : "Button label in the status bar while the model is generating. Tapping it cancels the current generation.",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Stop"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "停止"
          }
        }
      }
    },
    "Thinking" : {
      "comment" : "Header label of the collapsible thinking block rendered above the answer bubble when the model emits <think>…</think> content.",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Thinking"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "思考中"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

Note: keys are sorted alphabetically by Xcode convention (uppercase first, then lowercase, with `…` characters sorted after alphanumeric) — but the order is not significant for the catalog format. The plan sorts them to make diffs stable.

- [ ] **Step 3: Validate the JSON is well-formed**

Run:
```bash
python3 -c "import json; json.load(open('llm-visualizer/Resources/Localizable.xcstrings')); print('OK')"
```

Expected: `OK`.

If the command errors: re-check the file matches Step 2 exactly. Common mistakes: trailing comma, mismatched braces, unescaped quote inside a value.

- [ ] **Step 4: Build to confirm the file is picked up by Xcode**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

If the build fails because Xcode cannot find `Localizable.xcstrings` in the project navigator: open the project in Xcode once, drag the file from Finder into the `Resources` group in the navigator, save, and re-run the build. (The project uses `PBXFileSystemSynchronizedRootGroup` so the file should be auto-discovered, but a one-time Xcode open may be required after creating the `Resources/` directory.)

- [ ] **Step 5: Confirm no localization warnings**

Re-run the same build command from Step 4 and look at the full output (not just the tail):

```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -iE "warning|locali" | head -20
```

Expected: no `Localization` warnings (e.g. `String "X" is not localized even though 'Localizable.xcstrings' is present`).

If such a warning appears: the `Text("…")` literal in question isn't being matched against the catalog. Re-read the spec §5.2 — the bare string literal at that call site must be byte-for-byte identical to the catalog key. Common cause: invisible character mismatch (smart vs straight quotes, em-dash vs hyphen).

- [ ] **Step 6: Commit**

```bash
git add llm-visualizer/Resources/Localizable.xcstrings
git commit -m "feat(Resources): Localizable.xcstrings with en Base and zh-Hans"
```

---

## Task 2: Add `zh-Hans` to `knownRegions` in `project.pbxproj`

**Files:**
- Modify: `llm-visualizer.xcodeproj/project.pbxproj` (line 213-216)

No unit test — verified at build time (Xcode must recognize `zh-Hans` as a known region before the catalog's Chinese translations get compiled into the bundle).

- [ ] **Step 1: Read the current `knownRegions` block**

Read `llm-visualizer.xcodeproj/project.pbxproj` around line 213. Confirm it currently looks like:

```
			knownRegions = (
				en,
				Base,
			);
```

- [ ] **Step 2: Add `zh-Hans` after `en`**

Edit the `knownRegions` block to:

```
			knownRegions = (
				en,
				Base,
				"zh-Hans",
			);
```

Notes:
- Keep the leading tabs (the file uses tabs for indentation)
- `en,` has no quotes (it's an Xcode-known constant); `zh-Hans,` has quotes (it's a BCP-47 identifier with a hyphen)
- `Base,` is the Xcode-internal fallback language (never user-facing); leave it where it is
- The order does not matter functionally, but `en,` first matches the existing style

- [ ] **Step 3: Build to verify `zh-Hans` is recognized**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. (This time the build should also bundle the `zh-Hans` translations into the `.app`.)

If the build fails with a pbxproj parse error: re-check indentation. pbxproj is whitespace-sensitive — tabs vs spaces will break it. Restore from git, re-apply the edit carefully.

- [ ] **Step 4: Inspect the built bundle to confirm `zh-Hans` strings are present**

After a successful build, locate the built `.app` and look for compiled localizations. The path depends on the derived data location — the typical default is `~/Library/Developer/Xcode/DerivedData/`. Use the `xcodebuild` `-showBuildSettings` output to find it:

```bash
DD=$(xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -showBuildSettings -configuration Debug 2>/dev/null | grep -E "^\s+TARGET_BUILD_DIR" | head -1 | awk -F'= ' '{print $2}')
echo "Build dir: $DD"
ls "$DD/llm-visualizer.app/" | head -20
```

Expected: the `.app` bundle contents are listed. You should see localizations either as `*.lproj` folders or as compiled `.lproj` resources. If using `.xcstrings`, the build produces a `Localizable.lproj/` directory with the compiled `Localizable.strings` per language. Look for both `en.lproj` and `zh-Hans.lproj` (or similar structure):

```bash
ls "$DD/llm-visualizer.app/" | grep -i lproj
```

Expected: at least `en.lproj` and `zh-Hans.lproj` (or `Localizable.lproj/`) appear.

If only `en.lproj` shows: the catalog's `zh-Hans` translations aren't being recognized. Re-check Task 2 Step 2 — the `knownRegions` change is the most common cause.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer.xcodeproj/project.pbxproj
git commit -m "build(project): add zh-Hans to knownRegions"
```

---

## Task 3: Wrap the format string in `StatusBar.swift`

**Files:**
- Modify: `llm-visualizer/Views/Chat/StatusBar.swift:64`

No unit test — the change is a one-line wrap of an existing string in `String(localized:defaultValue:)`. Verified at build time + manual UI in Task 4.

- [ ] **Step 1: Read the current line 64**

Read `llm-visualizer/Views/Chat/StatusBar.swift` around lines 60-66. Confirm the current code is:

```swift
            if isGenerating {
                HStack(spacing: 6) {
                    statusDot(modelState, isGenerating: true)
                    Label(String(format: "Generating · %.1f t/s", tokensPerSecond),
                          systemImage: "circle.fill")
                        .foregroundStyle(.tint)
                }
```

- [ ] **Step 2: Replace the `Label(...)` call**

Replace the existing two-line `Label(...)` with:

```swift
            if isGenerating {
                HStack(spacing: 6) {
                    statusDot(modelState, isGenerating: true)
                    let format = String(
                        localized: "Generating · %.1f t/s",
                        defaultValue: "Generating · %.1f t/s"
                    )
                    Label(String(format: format, tokensPerSecond),
                          systemImage: "circle.fill")
                        .foregroundStyle(.tint)
                }
```

Why this works:
- `String(localized:defaultValue:)` (iOS 15+) explicitly registers the format pattern with the String Catalog. At runtime, the format itself (the literal `"生成中 · %.1f tokens/秒"` from the catalog) is loaded; the numeric placeholder `%.1f` is filled in by `String(format:)`.
- `defaultValue:` is a compile-time fallback identical to `localized:` — if the catalog ever loses the key, the build still works and English is shown.
- The bare-literal `Text("Loading model…")` calls elsewhere in this file need no source change — Xcode's String Catalog extractor picks them up automatically because they are `LocalizedStringKey` arguments.

- [ ] **Step 3: Build to verify no compile errors**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

If the build fails with "no member named 'localized' on 'StringProtocol'" or similar: you're likely running on an iOS deployment target older than 15.0. Check the project's deployment target — the spec assumes iOS 17.0+. If older, this task is blocked and needs a `NSLocalizedString` fallback.

- [ ] **Step 4: Run existing unit tests to confirm no regression**

Run:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'platform=iOS Simulator,name=iPhone 15' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

Expected:
- All existing test suites pass (`MessageTests`, `ThinkingParserTests`, etc.)
- No new test failures

If no simulator is available, run `build-for-testing` instead:
```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Views/Chat/StatusBar.swift
git commit -m "fix(Views): use String(localized:) for token-rate format string"
```

---

## Task 4: Manual end-to-end verification

**Files:** none (manual check only)

This task walks through the running app under both English and Simplified Chinese to confirm the spec §10 verification checklist passes. No commit.

- [ ] **Step 1: Cold launch on simulator (English locale)**

In Simulator: Settings → General → Language & Region → set iPhone Language to **English**, Region to **United States**. Force-quit the app and relaunch.

Open the project in Xcode 16+, select the `llm-visualizer` scheme, iPhone simulator destination, Cmd-R.

Expected on launch:
1. App launches, status bar shows "Initializing…" briefly, then "Loading model…", then green dot + "Ready"
2. Navigation bar title shows **"LLM Visualizer"**
3. All other strings (`Stop`, `Retry`, `Thinking`) display in English

If any of the 8 strings show in Chinese when language is English: the catalog's `en` localization is missing or has a typo. Re-check Task 1 Step 2.

- [ ] **Step 2: Trigger generation and verify the format string**

Send a prompt that triggers generation ("hi" is fine). During generation, the status bar should show:
**`Generating · 12.3 t/s`** (numbers will vary)

Expected: the format string interpolates the actual tokens/second value. The "·" middle-dot and "t/s" abbreviation match the English source.

- [ ] **Step 3: Trigger a thinking block**

Send a prompt that elicits a <think> block from Qwen3 (e.g. "用三步解释为什么天空是蓝色的").

Expected:
1. The ThinkingBlock header shows **"Thinking"** (not "思考中")
2. The body shows the model's reasoning in English/Chinese (model's choice, not affected by UI language)

- [ ] **Step 4: Switch system language to Simplified Chinese**

In Simulator: Settings → General → Language & Region → set iPhone Language to **简体中文 (Simplified Chinese)**, Region to **China Mainland**. Force-quit the app and relaunch.

Expected on launch:
1. Navigation bar title shows **"LLM 可视化"**
2. Status bar shows **"初始化中…"** briefly, then **"正在加载模型…"**, then green dot + **"就绪"**
3. During generation, status bar shows **`生成中 · 12.3 tokens/秒`** (note: "tokens/秒" replaces "t/s")
4. The Stop button label is **"停止"**
5. ThinkingBlock header shows **"思考中"** when a thinking block is present
6. If an error occurs, the Retry button shows **"重试"**

- [ ] **Step 5: Verify the format string in Chinese**

While generating in Chinese-locale mode, confirm the token rate format works:

Expected: `生成中 · 12.3 tokens/秒` displays correctly — the number is a single decimal, the units use "tokens/秒" (the Chinese translation from the catalog).

- [ ] **Step 6: Verify fallback to English for unsupported languages**

Set Simulator language to **Français (French)** (a language not in the catalog). Force-quit and relaunch.

Expected: all 8 strings display in **English** (the source language fallback). No half-translated state, no blank labels, no crash.

- [ ] **Step 7: Verify live language switch**

With the app running, change the system language in iOS Settings from English to 简体中文 (or vice versa). Return to the app.

Expected (per iOS version):
- iOS 17+: the running app may need to be backgrounded and re-foregrounded, or restarted, to pick up the new strings. **Strings do not change while the app is in the foreground** — this is platform-standard behavior, not a bug.
- After a force-quit and relaunch, all 8 strings should reflect the new language.

- [ ] **Step 8: Verify existing behavior unchanged**

In either language, confirm the rest of the app still works:
- Send a message → response streams in
- Tap Stop during generation → `[Cancelled]` appended to answer
- Tap trash icon → conversation clears
- App handles error states correctly

Expected: no regressions to existing functionality.

---

## Self-Review Checklist

After executing all tasks, verify:

- [ ] **Spec coverage:**
  - 8 strings localized (en + zh-Hans): Task 1 §2
  - String Catalog at `llm-visualizer/Resources/Localizable.xcstrings`: Task 1 §3
  - `knownRegions` includes `zh-Hans`: Task 2 §2
  - `StatusBar.swift:64` uses `String(localized:defaultValue:)`: Task 3 §2
  - Other 6 source sites untouched (Xcode auto-picks up bare literals): Task 3 §2 note
  - No code changes in `ChatView.swift`, `ThinkingBlock.swift`, `ChatViewModel.swift`: Task 3 §2 + spec §5.2
  - Build succeeds and bundle includes `zh-Hans.lproj`: Task 2 §4
  - English regression: Task 4 step 1
  - Chinese: Task 4 steps 4-5
  - Fallback to English for unsupported language: Task 4 step 6
  - Existing functionality unchanged: Task 4 step 8
  - LLM-generated content unaffected: not touched in any task
  - Error messages not localized: not touched in any task

- [ ] **TDD discipline:** Not applicable — no Swift logic added. Each task verified at build time and in Task 4 manually.

- [ ] **Commit cadence:** 3 commits (Tasks 1-3), 0 commits for Task 4 (manual only). Matches the spec §13 rollout plan.

- [ ] **No `ChatViewModel.swift` edit:** dynamic error content must remain untranslated per scope decision.

- [ ] **No app-name localization:** `CFBundleDisplayName` localization is a separate workflow, out of scope.

- [ ] **No in-app language switcher added:** system locale only, per scope decision.

- [ ] **All 8 keys present and translated in the catalog:** spot-check the JSON file before commit. Count of `state : translated` should be 16 (8 keys × 2 languages).

# LLM Visualizer — Pure Text Chat (Initial Slice)

**Date:** 2026-06-21
**Status:** Approved
**Target:** iOS 17.0+ (iPhone + iPad), Swift 5.9+

## 1. Goal

Ship the smallest useful slice of `llm-visualizer`: a pure text chat powered
by a fully **offline** local LLM (Qwen3-0.6B 4-bit DWQ), already downloaded
to the user's machine. No model downloads, no network access at runtime.
The slice is the foundation — later slices will add the "visualizer" parts
(KV cache, token probabilities, attention heatmaps, etc.).

## 2. Scope

**In scope (this slice):**
- Bundled local model loaded from `Bundle.main` on app launch
- Multi-turn text chat (user/assistant messages, system prompt, history)
- Streaming generation with token-by-token UI updates
- Generation metrics display (tokens/second)
- Cancel in-flight generation
- Reset conversation
- Error states for model load / generation failure

**Out of scope (this slice):**
- Model selection UI (only one model is bundled)
- Vision / multimodal input (text only)
- Media attachments (images, videos)
- Conversation persistence across launches
- Settings / configuration UI
- macOS support (iOS only)
- Tokenizer / KV cache / logit visualization (future slices)

## 3. Reference

Architecture and code patterns adapted from
`/Users/africamonkey/work/mlx-swift-examples/Applications/MLXChatExample/`
with simplifications (no VLM, no media, no `HubApi`).

## 4. Files

### 4.1 To delete
- `llm-visualizer/ContentView.swift`
- `llm-visualizer/Item.swift`

### 4.2 To create
```
llm-visualizer/
├── llm_visualizerApp.swift          # modified (see 4.3)
├── Resources/                       # NEW directory, holds the model folder
│   └── Qwen3-0.6B-4bit-DWQ-053125/  # moved from repo root
├── LLMVisualizer.entitlements       # NEW
├── Models/
│   ├── Message.swift                # NEW
│   └── ModelConfig.swift            # NEW
├── Services/
│   └── LLMService.swift             # NEW
├── ViewModels/
│   └── ChatViewModel.swift          # NEW
└── Views/
    ├── ChatView.swift               # NEW
    ├── ConversationView.swift       # NEW
    ├── MessageView.swift            # NEW
    ├── PromptField.swift            # NEW
    └── StatusBar.swift              # NEW
```

### 4.3 To modify
- `llm-visualizer/llm_visualizerApp.swift` — remove SwiftData references,
  instantiate `ChatViewModel`, hand it to `ChatView`
- `llm-visualizer.xcodeproj/project.pbxproj`:
  - Lower `IPHONEOS_DEPLOYMENT_TARGET` from `26.2` to `17.0` for the app
    and test targets
  - Add `LLMVisualizer.entitlements` reference
  - Add Swift Package dependencies (`mlx-swift`, `mlx-swift-lm`,
    `swift-transformers`) and link the product libraries
  - Add `Qwen3-0.6B-4bit-DWQ-053125/` as a folder reference in the
    `PBXResourcesBuildPhase` of the main target

## 5. Architecture (MVVM)

```
┌─────────────┐         ┌──────────────────┐         ┌──────────────┐
│   ChatView  │ ──────▶ │  ChatViewModel   │ ──────▶ │  LLMService  │
│  (SwiftUI)  │ ◀────── │   (@Observable)  │ ◀────── │              │
└─────────────┘         └──────────────────┘         └──────────────┘
                              │                            │
                              ▼                            ▼
                        [Message]                  ModelContainer
                        generateTask               AsyncStream<Generation>
```

### 5.1 Models
- `Message` — `struct` (Sendable-friendly), `id: UUID`, `role: Role`,
  `content: String`, `timestamp: Date`. Role enum: `.user / .assistant /
  .system`. Factory methods: `.user(_:)`, `.assistant(_:)`,
  `.system(_:)`.
- `ModelConfig` — namespace of `static let` constants:
  - `directory: URL` — `Bundle.main.bundleURL.appending(path:
    "Qwen3-0.6B-4bit-DWQ-053125")`
  - `id: String` — `"mlx-community/Qwen3-0.6B-4bit-DWQ-053125"`
  - `configuration: ModelConfiguration` — `ModelConfiguration(directory:
    directory, id: id)`
  - `parameters: GenerateParameters` — temperature 0.6, topP 0.95, topK 20
    (from `generation_config.json`)

### 5.2 Services
- `LLMService` — `@MainActor` class, single instance per app:
  - Private `NSCache<NSString, ModelContainer>` (one entry)
  - `loadModel() async throws -> ModelContainer` — sets
    `Memory.cacheLimit = 20 * 1024 * 1024`, returns cached container if
    present, otherwise loads via `LLMModelFactory.shared.loadContainer(
    from: HubApi(), using: HuggingFaceTokenizerLoader(), configuration:
    ModelConfig.configuration)`. **No download** because `directory:`
    points inside the bundle.
  - `generate(messages: [Message], model: ModelContainer) async throws
    -> AsyncStream<Generation>` — strips trailing empty assistant
    message, maps `Message` → `Chat.Message`, builds `UserInput`,
    calls `MLXLMCommon.generate(input:lmInput, parameters: ..., context:
    context)` inside `modelContainer.perform { ... }`.

### 5.3 ViewModel
- `ChatViewModel` — `@MainActor @Observable`:
  - `messages: [Message]` — starts with `.system("You are a helpful
    assistant.")`
  - `prompt: String`
  - `modelState: ModelState` — `.idle / .loading / .loaded /
    .error(String)`
  - `tokensPerSecond: Double`
  - `isGenerating: Bool`
  - `errorBanner: String?` — transient top-of-screen error, auto-clears
    after 3s
  - Private `service: LLMServiceProtocol`
  - Private `modelContainer: ModelContainer?`
  - Private `generateTask: Task<Void, Never>?`
  - Methods:
    - `bootstrap() async` — `modelState = .loading`, load model, on
      success `.loaded`, on failure `.error(msg)`
    - `generate() async` — see data flow §6.1
    - `cancel()` — see §6.2
    - `reset()` — see §6.3
    - `retryLoad() async` — same as `bootstrap`, called from StatusBar

### 5.4 Views
- `ChatView` — root view. Holds `ChatViewModel`. Layout: `VStack {
  ConversationView, Divider, PromptField, StatusBar }` inside
  `NavigationStack`. Triggers `vm.bootstrap()` via `.task`.
- `ConversationView` — `ScrollView { LazyVStack { ForEach(messages) {
  MessageView($0) } } }`, `defaultScrollAnchor(.bottom)`.
- `MessageView` — branches on `role`:
  - `.user` — right-aligned bubble with tinted background
  - `.assistant` — left-aligned plain text
  - `.system` — centered label with computer icon
  - Uses `Text(LocalizedStringKey(content))` for native markdown
  - `.textSelection(.enabled)`
- `PromptField` — `TextField` + send button only. Calls
  `vm.generate()`. Disabled when `vm.isGenerating` is true (so the
  user cannot queue a second message). Cmd+. calls `vm.cancel()`
  regardless of state.
- `StatusBar` — see §6.4. The cancel button shown while generating
  also calls `vm.cancel()`.

## 6. Data Flow

### 6.1 `generate()`
1. If `generateTask != nil` → cancel it. (Defensive — in normal use the
   send button is disabled while generating, so this handles races
   from keyboard shortcuts.)
2. If `prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`
   → return.
3. `messages.append(.user(prompt))`
4. `messages.append(.assistant(""))` (placeholder)
5. `prompt = ""`
6. `isGenerating = true`
7. `generateTask = Task { @MainActor in`
   - `for await gen in try service.generate(messages: messages, model:
     modelContainer)`
   - `switch gen { case .chunk(let s): messages[messages.count - 1].content
     += s; case .info(let i): tokensPerSecond = i.tokensPerSecond; case
     .toolCall: break }`
   - catch `CancellationError`: append `\n[Cancelled]` to last message
   - catch other errors: set `errorBanner = error.localizedDescription`
     and schedule auto-clear in 3 s
   - `isGenerating = false; generateTask = nil`

### 6.2 `cancel()`
- `generateTask?.cancel()`
- The catch block in §6.1 appends `[Cancelled]` to the last assistant
  message

### 6.3 `reset()`
- `generateTask?.cancel()`
- `messages = [.system("You are a helpful assistant.")]`
- `prompt = ""`
- `tokensPerSecond = 0`
- `errorBanner = nil`
- `modelState` unchanged (model stays cached)

### 6.4 `StatusBar` rendering
| `modelState` | `isGenerating` | UI |
|---|---|---|
| `.idle` | – | hidden (or "Initializing…") |
| `.loading` | – | `ProgressView()` + "Loading model…" |
| `.loaded` | false | empty / model name |
| `.loaded` | true | `● Generating · 23.4 t/s` + cancel button |
| `.error(msg)` | – | `✕ \(msg)` (red) + "Retry" button |

Reset button (trash icon) shown when `messages.count > 1`.

## 7. Model Bundling

### 7.1 Move model
- `mv ~/work/llm-visualizer/Qwen3-0.6B-4bit-DWQ-053125
  ~/work/llm-visualizer/llm-visualizer/Resources/Qwen3-0.6B-4bit-DWQ-053125`

### 7.2 Xcode project
- Add `PBXFileReference` for the folder with `lastKnownFileType = folder`
  (folder reference — preserves directory structure when copied to bundle)
- Add `PBXBuildFile` and add to `PBXResourcesBuildPhase` of the
  `llm-visualizer` target
- After build, the bundle contains
  `llm-visualizer.app/Qwen3-0.6B-4bit-DWQ-053125/{config.json,
  model.safetensors, tokenizer.json, ...}`

### 7.3 Entitlements
`LLMVisualizer.entitlements`:
```xml
<key>com.apple.developer.kernel.increased-memory-limit</key>
<true/>
```

## 8. Swift Package Dependencies

| Package URL | Version constraint | Products used |
|---|---|---|
| `https://github.com/ml-explore/mlx-swift` | `0.31.4 ... <0.32.0` | `MLX` |
| `https://github.com/ml-explore/mlx-swift-lm` | latest | `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace` |
| `https://github.com/huggingface/swift-transformers` | `1.3.0 ... <2.0.0` | `Tokenizers`, `HuggingFace` |

Mirrors what `MLXChatExample` uses, except `MLXVLM` and `VLMModelFactory`
which are not needed.

## 9. iOS Deployment Target

`IPHONEOS_DEPLOYMENT_TARGET` lowered from `26.2` (Xcode default) to
`17.0`. Required to remove `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
quirks and to widen device coverage. Test targets also lowered to 17.0.
MLX requires Apple Silicon, so the practical minimum device is A14+
(iPhone 12+, iPad Air 4+).

## 10. Error Handling

| Source | Trigger | UI | Recovery |
|---|---|---|---|
| Model dir missing | `Bundle.main/.../Qwen3-...` doesn't exist | Status bar: `✕ Model not found` | Restart app |
| Load failure | corrupt safetensors, missing config | Status bar: `✕ \(err)` (red) | "Retry" button |
| Generation cancel | `Task.cancel()` | `\n[Cancelled]` on last message | silent |
| Generation error | OOM, tokenizer error | Top red banner, 3s auto-clear | send new message |
| Empty prompt | user sends blank | Send button disabled | — |

## 11. Memory Management

- `Memory.cacheLimit = 20 * 1024 * 1024` (20 MB GPU cache) at load time
- `ModelContainer` cached in `NSCache` for app lifetime
- App sandboxes write nothing to the model directory; reading the
  bundle is sufficient

## 12. Testing

### Unit (`llm-visualizerTests/`)
- `MessageTests`
  - factory methods set correct role/content
  - `id` is unique across instances
- `ChatViewModelTests` (uses `LLMServiceProtocol` mock)
  - `generate()` with non-empty prompt appends user + placeholder
  - `generate()` with empty prompt is a no-op
  - two `generate()` calls in a row cancel the first
  - `cancel()` sets `isGenerating = false`
  - `reset()` keeps the system message, clears user/assistant messages
  - stream chunks append to the last assistant message
  - `info` updates `tokensPerSecond`

### UI (`llm-visualizerUITests/`)
- `testEmptyState` — launch, see PromptField + StatusBar
- `testLoadingThenReady` — StatusBar text transitions from "Loading"
  to "Ready"
- `testSendAndReceive` — type "Hi", send, see both messages
- `testCancelGeneration` — send, immediately stop, see `[Cancelled]`
- `testResetClearsConversation` — after multiple turns, reset, see only
  system message

### Manual
- Real-device/simulator: load → conversation → cancel → reset →
  conversation
- Confirm `t/s` updates in real time
- Confirm model directory is in `.app` bundle after build
- Confirm `Memory.cacheLimit` takes effect (Instruments or print)

### TDD order
1. `Message` struct + factories
2. `ModelConfig` constants
3. `LLMServiceProtocol` + mock
4. `ChatViewModel` core methods
5. `LLMService` real implementation
6. SwiftUI views (manual visual check first; UI tests last)

## 13. Out of Scope / Future Slices

- macOS support
- Conversation persistence (SwiftData or files)
- Model selection UI
- Vision / multimodal
- "Visualizer" features: KV cache, attention, logit distribution
- Streaming markdown / code highlighting
- Tokenizer inspection
- Performance profiler overlay

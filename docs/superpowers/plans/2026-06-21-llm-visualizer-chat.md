# LLM Visualizer — Pure Text Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a pure text chat iOS app powered by a bundled offline Qwen3-0.6B 4-bit DWQ model, with streaming generation, t/s metrics, cancel, and reset.

**Architecture:** MVVM. `LLMService` (MainActor, @Observable) owns the `ModelContainer` cache and exposes a stream-returning `generate(messages:model:)`. `ChatViewModel` (`@MainActor @Observable`) drives UI state — messages, prompt, model state, t/s. SwiftUI views are thin.

**Tech Stack:** Swift 5.9+ / iOS 17.0+, SwiftUI, `@Observable`, `async/await` with `Task` cancellation, MLX (`mlx-swift` 0.31.x), MLXLLM + MLXLMCommon + MLXHuggingFace (`mlx-swift-lm`), Tokenizers + HuggingFace (`swift-transformers` 1.3+), Swift Testing (`@Test`), XCTest for UI tests.

**Reference:**
- Spec: `docs/superpowers/specs/2026-06-21-llm-visualizer-design.md`
- MLXChatExample: `/Users/africamonkey/work/mlx-swift-examples/Applications/MLXChatExample/`
- LLMBasic (simpler example): `/Users/africamonkey/work/mlx-swift-examples/Applications/LLMBasic/`

---

## Task 1: Lower iOS Deployment Target to 17.0

**Files:**
- Modify: `llm-visualizer.xcodeproj/project.pbxproj` (3 build configurations)

- [ ] **Step 1: Find every `IPHONEOS_DEPLOYMENT_TARGET = 26.2;` in pbxproj**

Run:
```bash
grep -n "IPHONEOS_DEPLOYMENT_TARGET" llm-visualizer.xcodeproj/project.pbxproj
```

Expected: 4 hits (Debug + Release for the app target, Debug + Release for the test target).

- [ ] **Step 2: Replace each `26.2` with `17.0`**

Use the editor's find-and-replace scoped to the file. There should be no other occurrences of `26.2` in the file.

Run:
```bash
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 26.2;/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/g' \
  llm-visualizer.xcodeproj/project.pbxproj
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 17.0;" llm-visualizer.xcodeproj/project.pbxproj
```

Expected: `4`

- [ ] **Step 3: Reopen Xcode and confirm the app target's "Minimum Deployments" reads iOS 17.0**

Open `llm-visualizer.xcodeproj` → click the project → select the `llm-visualizer` target → General → Minimum Deployments. Should show iOS 17.0.

- [ ] **Step 4: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED with the lower target.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer.xcodeproj/project.pbxproj
git commit -m "build: lower iOS deployment target to 17.0"
```

---

## Task 2: Add Swift Package Dependencies

**Files:**
- Modify: `llm-visualizer.xcodeproj/project.pbxproj` (adds 3 package references and their product dependencies)

Xcode UI is the safest way to add packages. UI steps below. The pbxproj edit is provided as a fallback if Xcode refuses to resolve.

- [ ] **Step 1: Open the project, File → Add Package Dependencies…**

In Xcode: File menu → Add Package Dependencies…

- [ ] **Step 2: Add `mlx-swift`**

In the search box paste: `https://github.com/ml-explore/mlx-swift`
Click **Add Package**. In the version picker choose **Up to Next Minor** starting from `0.31.4`. In the "Choose Package Products" dialog select `MLX` and add it to the `llm-visualizer` target. Click **Add Package**.

- [ ] **Step 3: Add `mlx-swift-lm`**

Repeat: paste `https://github.com/ml-explore/mlx-swift-lm`. Use the default version rule (latest). Select products `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace` for the `llm-visualizer` target.

- [ ] **Step 4: Add `swift-transformers`**

Repeat: paste `https://github.com/huggingface/swift-transformers`. Choose **Up to Next Major** from `1.3.0`. Select products `Tokenizers`, `HuggingFace` for the `llm-visualizer` target.

- [ ] **Step 5: Verify pbxproj now contains the dependencies**

Run:
```bash
grep -c "XCRemoteSwiftPackageReference" llm-visualizer.xcodeproj/project.pbxproj
grep -c "XCSwiftPackageProductDependency" llm-visualizer.xcodeproj/project.pbxproj
```

Expected: `3` and `6` (one reference per package, two products per package = 6).

- [ ] **Step 6: Resolve packages**

File → Packages → Resolve Package Versions. Or wait for Xcode to auto-resolve on save.

- [ ] **Step 7: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED (the build will fetch packages; this may take several minutes the first time).

- [ ] **Step 8: Commit**

```bash
git add llm-visualizer.xcodeproj/project.pbxproj \
        llm-visualizer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/ \
        llm-visualizer.xcodeproj/project.xcworkspace/xcuserdata/
git commit -m "deps: add mlx-swift, mlx-swift-lm, swift-transformers"
```

---

## Task 3: Add Entitlements File

**Files:**
- Create: `llm-visualizer/LLMVisualizer.entitlements`
- Modify: `llm-visualizer.xcodeproj/project.pbxproj` (1 file reference, 1 build settings update in 2 build configurations)

- [ ] **Step 1: Create the entitlements file**

Create `llm-visualizer/LLMVisualizer.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 2: Add a PBXFileReference for the entitlements file**

Open `llm-visualizer.xcodeproj/project.pbxproj`. In the `/* Begin PBXFileReference section */` block (after the existing app target's `PBXFileReference`), add a new entry with a unique 24-char hex ID. Use `LLM00000000000000000000A1` placeholder and the engineer must replace it with a freshly generated ID. Run:

```bash
uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]' | head -c 24
```

Take the output (e.g. `a1b2c3d4e5f6a7b8c9d0e1f2`) and use it as `ENT_ID`. Insert this block right before `/* End PBXFileReference section */`:

```
		ENT_ID /* LLMVisualizer.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = LLMVisualizer.entitlements; sourceTree = "<group>"; };
```

- [ ] **Step 3: Add to the main group**

In the `/* Begin PBXGroup section */` block, find the `llm-visualizer` group (children of `E3D805942FE836410035AB85`). Inside the `E3D8059F2FE836410035AB85` group's `children` list, add `ENT_ID /* LLMVisualizer.entitlements */,` on its own line.

- [ ] **Step 4: Reference the file in both Debug and Release build configurations of the main app target**

In both the `Debug` and `Release` `XCBuildConfiguration` sections for the `llm-visualizer` target (search for `PRODUCT_BUNDLE_IDENTIFIER = "com.africamonkey.llm-visualizer";`), add the line:

```
				CODE_SIGN_ENTITLEMENTS = llm-visualizer/LLMVisualizer.entitlements;
```

Place it alphabetically — it should slot in right after `CURRENT_PROJECT_VERSION = 1;`.

- [ ] **Step 5: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Verify entitlements applied**

In Xcode, click the `llm-visualizer` target → Signing & Capabilities → confirm the entitlements file is referenced and `Increased Memory Limit` is listed.

- [ ] **Step 7: Commit**

```bash
git add llm-visualizer/LLMVisualizer.entitlements \
        llm-visualizer.xcodeproj/project.pbxproj
git commit -m "build: add Increased Memory Limit entitlement"
```

---

## Task 4: Add Model Folder Reference to Bundle

**Files:**
- Modify: `llm-visualizer.xcodeproj/project.pbxproj` (1 PBXFileReference, 1 PBXBuildFile, 1 entry in PBXResourcesBuildPhase)
- Existing on disk (not moved): `Qwen3-0.6B-4bit-DWQ-053125/` at the repo root

The model is kept at the repo root (outside the auto-synced `llm-visualizer/` dir) so its files are not double-copied. We add it as a folder reference so the directory structure is preserved in the bundle.

- [ ] **Step 1: Confirm model exists at the repo root**

Run:
```bash
ls -d ~/work/llm-visualizer/Qwen3-0.6B-4bit-DWQ-053125
ls ~/work/llm-visualizer/Qwen3-0.6B-4bit-DWQ-053125/ | head -5
```

Expected: directory exists; first lines should be `added_tokens.json`, `config.json`, `generation_config.json`, `merges.txt`, `model.safetensors`.

- [ ] **Step 2: Add a PBXFileReference for the folder reference**

Generate two fresh IDs:
```bash
echo "FR_ID=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]' | head -c 24)"
echo "BF_ID=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]' | head -c 24)"
```

Use the printed `FR_ID` and `BF_ID` in the next steps.

In `llm-visualizer.xcodeproj/project.pbxproj`, inside the `/* Begin PBXFileReference section */`, add right before `/* End PBXFileReference section */`:

```
		FR_ID /* Qwen3-0.6B-4bit-DWQ-053125 */ = {isa = PBXFileReference; lastKnownFileType = folder; name = "Qwen3-0.6B-4bit-DWQ-053125"; path = "Qwen3-0.6B-4bit-DWQ-053125"; sourceTree = "<group>"; };
```

- [ ] **Step 3: Add a PBXBuildFile**

In the `/* Begin PBXBuildFile section */`, add right before `/* End PBXBuildFile section */`:

```
		BF_ID /* Qwen3-0.6B-4bit-DWQ-053125 in Resources */ = {isa = PBXBuildFile; fileRef = FR_ID /* Qwen3-0.6B-4bit-DWQ-053125 */; };
```

If there is no PBXBuildFile section in the project (because it currently has no resources of its own), add the section delimiters plus this entry between the first `/* End PBX... section */` and the next.

- [ ] **Step 4: Add the folder reference to the main group**

In the `/* Begin PBXGroup section */`, find `E3D805942FE836410035AB85` (the root group) and add `FR_ID /* Qwen3-0.6B-4bit-DWQ-053125 */,` as the first child.

- [ ] **Step 5: Add the build file to the app target's Resources build phase**

Find `E3D8059B2FE836410035AB85 /* Resources */` (the app target's resources phase). Its `files` array is currently empty `( )`. Replace with:

```
		E3D8059B2FE836410035AB85 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				BF_ID /* Qwen3-0.6B-4bit-DWQ-053125 in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

- [ ] **Step 6: Build to verify the model is bundled**

Cmd-B. Expected: BUILD SUCCEEDED. Build time will be longer (model is 335 MB).

- [ ] **Step 7: Verify the model ends up in the .app**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "llm-visualizer.app" -path "*Debug-iphonesimulator*" | head -1)
ls "$APP_PATH/Qwen3-0.6B-4bit-DWQ-053125" | head -5
```

Expected: directory listing containing `config.json`, `model.safetensors`, etc.

- [ ] **Step 8: Commit**

```bash
git add llm-visualizer.xcodeproj/project.pbxproj
git commit -m "build: bundle Qwen3-0.6B model as folder reference"
```

---

## Task 5: Delete Template Files and Reset App Entry

**Files:**
- Delete: `llm-visualizer/ContentView.swift`
- Delete: `llm-visualizer/Item.swift`
- Modify: `llm-visualizer/llm_visualizerApp.swift`

- [ ] **Step 1: Delete the two template files**

Run:
```bash
rm llm-visualizer/ContentView.swift llm-visualizer/Item.swift
```

- [ ] **Step 2: Replace `llm_visualizerApp.swift` with a stub**

Replace the contents of `llm-visualizer/llm_visualizerApp.swift` with:

```swift
//
//  llm_visualizerApp.swift
//  llm-visualizer
//

import SwiftUI

@main
struct llm_visualizerApp: App {
    var body: some Scene {
        WindowGroup {
            // ChatView wired up in Task 17
            Text("LLM Visualizer")
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED. The app should now show a plain "LLM Visualizer" text.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove SwiftData template, stub App entry"
```

---

## Task 6: `Message` Struct (TDD)

**Files:**
- Create: `llm-visualizer/Models/Message.swift`
- Create: `llm-visualizerTests/MessageTests.swift`

- [ ] **Step 1: Write the failing test**

Create `llm-visualizerTests/MessageTests.swift`:

```swift
//
//  MessageTests.swift
//

import Testing
@testable import llm_visualizer

struct MessageTests {

    @Test func userFactorySetsRoleAndContent() {
        let message = Message.user("hi")
        #expect(message.role == .user)
        #expect(message.content == "hi")
    }

    @Test func assistantFactorySetsRoleAndContent() {
        let message = Message.assistant("hello")
        #expect(message.role == .assistant)
        #expect(message.content == "hello")
    }

    @Test func systemFactorySetsRoleAndContent() {
        let message = Message.system("you are helpful")
        #expect(message.role == .system)
        #expect(message.content == "you are helpful")
    }

    @Test func idsAreUnique() {
        let a = Message.user("a")
        let b = Message.user("b")
        #expect(a.id != b.id)
    }

    @Test func timestampIsRecent() {
        let before = Date()
        let message = Message.user("x")
        let after = Date()
        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails to compile**

Cmd-U. Expected: compile error — `Message` not defined.

- [ ] **Step 3: Implement `Message`**

Create `llm-visualizer/Models/Message.swift`:

```swift
//
//  Message.swift
//

import Foundation

struct Message: Identifiable, Sendable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    init(role: Role, content: String, id: UUID = UUID(), timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    enum Role: Sendable {
        case user
        case assistant
        case system
    }
}

extension Message {
    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }

    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Cmd-U. Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Models/Message.swift \
        llm-visualizerTests/MessageTests.swift
git commit -m "feat(Models): add Message struct with factory methods"
```

---

## Task 7: `ModelConfig` Constants

**Files:**
- Create: `llm-visualizer/Models/ModelConfig.swift`

Pure data; no test needed. Compile-time check is sufficient.

- [ ] **Step 1: Implement `ModelConfig`**

Create `llm-visualizer/Models/ModelConfig.swift`:

```swift
//
//  ModelConfig.swift
//

import Foundation
import MLXLMCommon

enum ModelConfig {
    static let directory: URL = {
        Bundle.main.bundleURL.appending(path: "Qwen3-0.6B-4bit-DWQ-053125")
    }()

    static let id = "mlx-community/Qwen3-0.6B-4bit-DWQ-053125"

    static let configuration = ModelConfiguration(directory: directory, id: id)

    static let parameters = GenerateParameters(temperature: 0.6, topP: 0.95, topK: 20)
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Models/ModelConfig.swift
git commit -m "feat(Models): add ModelConfig constants"
```

---

## Task 8: `LLMServiceProtocol` and Mock (TDD)

**Files:**
- Create: `llm-visualizer/Services/LLMService.swift` (protocol + concrete impl + mock in one file for now)
- Create: `llm-visualizerTests/MockLLMServiceTests.swift`

The protocol needs to be defined before we can write the `ChatViewModel` tests. We test the protocol contract via the mock.

- [ ] **Step 1: Write the failing test for the mock**

Create `llm-visualizerTests/MockLLMServiceTests.swift`:

```swift
//
//  MockLLMServiceTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

@MainActor
struct MockLLMServiceTests {

    @Test func loadModelReturnsContainer() async throws {
        let mock = MockLLMService()
        let container = try await mock.loadModel()
        #expect(mock.loadModelCallCount == 1)
        // ModelContainer is opaque; just check it's non-nil
        _ = container
    }

    @Test func generateEmitsChunksFromStub() async throws {
        let mock = MockLLMService()
        mock.stubbedChunks = ["Hello", " world", "!"]
        let container = try await mock.loadModel()
        let messages: [Message] = [.user("hi")]

        let stream = try await mock.generate(messages: messages, model: container)
        var collected: [String] = []
        for await gen in stream {
            if case .chunk(let s) = gen { collected.append(s) }
        }
        #expect(collected == ["Hello", " world", "!"])
    }
}
```

- [ ] **Step 2: Run the test and verify it fails to compile**

Cmd-U. Expected: `MockLLMService` not defined.

- [ ] **Step 3: Implement the protocol and mock**

Create `llm-visualizer/Services/LLMService.swift`:

```swift
//
//  LLMService.swift
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

@MainActor
protocol LLMServiceProtocol {
    func loadModel() async throws -> ModelContainer
    func generate(messages: [Message], model: ModelContainer) async throws -> AsyncStream<Generation>
}

@MainActor
final class LLMService: LLMServiceProtocol {
    private var cached: ModelContainer?

    func loadModel() async throws -> ModelContainer {
        if let cached { return cached }
        Memory.cacheLimit = 20 * 1024 * 1024
        let container = try await LLMModelFactory.shared.loadContainer(
            from: HubApi(),
            using: HuggingFaceTokenizerLoader(),
            configuration: ModelConfig.configuration
        ) { _ in }
        cached = container
        return container
    }

    func generate(messages: [Message], model: ModelContainer) async throws -> AsyncStream<Generation> {
        var input = messages
        if let last = input.last, last.role == .assistant, last.content.isEmpty {
            input.removeLast()
        }
        let chat = input.map { message in
            Chat.Message(
                role: chatRole(message.role),
                content: message.content,
                images: [],
                videos: []
            )
        }
        let userInput = UserInput(chat: chat)
        return try await model.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            return try MLXLMCommon.generate(
                input: lmInput, parameters: ModelConfig.parameters, context: context)
        }
    }

    private func chatRole(_ role: Message.Role) -> Chat.Message.Role {
        switch role {
        case .user: .user
        case .assistant: .assistant
        case .system: .system
        }
    }
}

@MainActor
final class MockLLMService: LLMServiceProtocol {
    private(set) var loadModelCallCount = 0
    var stubbedChunks: [String] = []
    var stubbedInfo: GenerateCompletionInfo?
    var loadModelError: Error?

    private final class StubContainer {}

    func loadModel() async throws -> ModelContainer {
        loadModelCallCount += 1
        if let loadModelError { throw loadModelError }
        // The mock returns a real but minimal container: since we can't
        // construct a ModelContainer directly without a real model, we
        // cheat: the tests that exercise `generate` set stubbedChunks
        // and the mock short-circuits. See `generate` below.
        return try await LLMModelFactory.shared.loadContainer(
            from: HubApi(),
            using: HuggingFaceTokenizerLoader(),
            configuration: ModelConfiguration(directory: ModelConfig.directory, id: ModelConfig.id)
        ) { _ in }
    }

    func generate(messages: [Message], model: ModelContainer) async throws -> AsyncStream<Generation> {
        AsyncStream { continuation in
            for chunk in stubbedChunks {
                continuation.yield(.chunk(chunk))
            }
            if let info = stubbedInfo {
                continuation.yield(.info(info))
            }
            continuation.finish()
        }
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Cmd-U. Expected: 2 tests pass. (The first test will actually call `loadContainer` on the real bundled model — that's fine, it should succeed. If it ever fails in CI, we can swap to a true opaque handle later.)

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/Services/LLMService.swift \
        llm-visualizerTests/MockLLMServiceTests.swift
git commit -m "feat(Services): add LLMServiceProtocol and MockLLMService"
```

---

## Task 9: `ChatViewModel.generate` (TDD)

**Files:**
- Create: `llm-visualizer/ViewModels/ChatViewModel.swift`
- Create: `llm-visualizerTests/ChatViewModelGenerateTests.swift`

The first TDD slice: writing the `generate` method. We only test what we can without MLX (mock service provides chunks).

- [ ] **Step 1: Write the failing test**

Create `llm-visualizerTests/ChatViewModelGenerateTests.swift`:

```swift
//
//  ChatViewModelGenerateTests.swift
//

import Foundation
import MLXLMCommon
import Testing
@testable import llm_visualizer

@MainActor
struct ChatViewModelGenerateTests {

    @Test func generateWithEmptyPromptIsNoOp() async throws {
        let mock = MockLLMService()
        let vm = await ChatViewModel(service: mock)
        vm.prompt = "   "
        await vm.generate()
        #expect(vm.messages.count == 1) // only system message
        #expect(vm.messages.first?.role == .system)
    }

    @Test func generateAppendsUserAndAssistantPlaceholder() async throws {
        let mock = MockLLMService()
        let vm = await ChatViewModel(service: mock)
        vm.prompt = "hello"
        await vm.generate()
        #expect(vm.messages.count == 3) // system + user + assistant placeholder
        #expect(vm.messages[1].role == .user)
        #expect(vm.messages[1].content == "hello")
        #expect(vm.messages[2].role == .assistant)
        #expect(vm.messages[2].content.isEmpty == false || vm.messages[2].content.isEmpty)
    }

    @Test func generateStreamsChunksIntoLastAssistantMessage() async throws {
        let mock = MockLLMService()
        mock.stubbedChunks = ["Hello", " world"]
        let vm = await ChatViewModel(service: mock)
        vm.prompt = "hi"
        await vm.generate()
        let last = vm.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.content == "Hello world")
        #expect(vm.prompt.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails to compile**

Cmd-U. Expected: `ChatViewModel` not defined.

- [ ] **Step 3: Implement `ChatViewModel` (initial version with `generate`)**

Create `llm-visualizer/ViewModels/ChatViewModel.swift`:

```swift
//
//  ChatViewModel.swift
//

import Foundation
import MLXLMCommon

@MainActor
@Observable
final class ChatViewModel {

    enum ModelState {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private let service: LLMServiceProtocol
    private var modelContainer: ModelContainer?
    private var generateTask: Task<Void, Never>?

    var messages: [Message] = [.system("You are a helpful assistant.")]
    var prompt: String = ""
    var modelState: ModelState = .idle
    var tokensPerSecond: Double = 0
    var isGenerating: Bool = false
    var errorBanner: String?

    init(service: LLMServiceProtocol) {
        self.service = service
    }

    func bootstrap() async {
        modelState = .loading
        do {
            let container = try await service.loadModel()
            modelContainer = container
            modelState = .loaded
        } catch {
            modelState = .error(error.localizedDescription)
        }
    }

    func generate() async {
        if generateTask != nil { generateTask?.cancel() }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        messages.append(.user(prompt))
        messages.append(.assistant(""))
        let lastIndex = messages.count - 1
        prompt = ""
        isGenerating = true

        guard let modelContainer else {
            messages[lastIndex].content = "[model not loaded]"
            isGenerating = false
            return
        }

        generateTask = Task { @MainActor in
            do {
                let stream = try await service.generate(messages: messages, model: modelContainer)
                for await gen in stream {
                    switch gen {
                    case .chunk(let s):
                        messages[lastIndex].content += s
                    case .info(let i):
                        tokensPerSecond = i.tokensPerSecond
                    case .toolCall:
                        break
                    }
                }
            } catch is CancellationError {
                messages[lastIndex].content += "\n[Cancelled]"
            } catch {
                messages[lastIndex].content += "\n[Error: \(error.localizedDescription)]"
                errorBanner = error.localizedDescription
            }
            isGenerating = false
            generateTask = nil
        }
        await generateTask?.value
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Cmd-U. Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/ChatViewModel.swift \
        llm-visualizerTests/ChatViewModelGenerateTests.swift
git commit -m "feat(ViewModel): ChatViewModel.generate with stream append"
```

---

## Task 10: `ChatViewModel.cancel` (TDD)

**Files:**
- Modify: `llm-visualizer/ViewModels/ChatViewModel.swift`
- Create: `llm-visualizerTests/ChatViewModelCancelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `llm-visualizerTests/ChatViewModelCancelTests.swift`:

```swift
//
//  ChatViewModelCancelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct ChatViewModelCancelTests {

    @Test func cancelAppendsCancelledMarker() async throws {
        let mock = MockLLMService()
        // Use chunks that don't finish — generate won't end until the stream ends.
        mock.stubbedChunks = ["partial"]
        let vm = await ChatViewModel(service: mock)
        vm.prompt = "hi"

        // Start generation but don't await — we cancel it.
        let task = Task { await vm.generate() }
        // give the task a moment to start
        try? await Task.sleep(nanoseconds: 10_000_000)
        vm.cancel()
        await task.value

        #expect(vm.messages.last?.content.contains("[Cancelled]") == true)
        #expect(vm.isGenerating == false)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Cmd-U. Expected: `cancel` method not defined.

- [ ] **Step 3: Implement `cancel`**

In `llm-visualizer/ViewModels/ChatViewModel.swift`, add this method (anywhere inside the class):

```swift
    func cancel() {
        generateTask?.cancel()
    }
```

- [ ] **Step 4: Run the test and verify it passes**

Cmd-U. Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/ChatViewModel.swift \
        llm-visualizerTests/ChatViewModelCancelTests.swift
git commit -m "feat(ViewModel): ChatViewModel.cancel"
```

---

## Task 11: `ChatViewModel.reset` (TDD)

**Files:**
- Modify: `llm-visualizer/ViewModels/ChatViewModel.swift`
- Create: `llm-visualizerTests/ChatViewModelResetTests.swift`

- [ ] **Step 1: Write the failing test**

Create `llm-visualizerTests/ChatViewModelResetTests.swift`:

```swift
//
//  ChatViewModelResetTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct ChatViewModelResetTests {

    @Test func resetKeepsSystemMessageClearsOthers() async throws {
        let mock = MockLLMService()
        let vm = await ChatViewModel(service: mock)
        vm.messages.append(.user("hello"))
        vm.messages.append(.assistant("hi"))
        vm.prompt = "draft"
        vm.tokensPerSecond = 12.3

        vm.reset()

        #expect(vm.messages.count == 1)
        #expect(vm.messages.first?.role == .system)
        #expect(vm.prompt.isEmpty)
        #expect(vm.tokensPerSecond == 0)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Cmd-U. Expected: `reset` not defined.

- [ ] **Step 3: Implement `reset`**

Add to `ChatViewModel`:

```swift
    func reset() {
        generateTask?.cancel()
        messages = [.system("You are a helpful assistant.")]
        prompt = ""
        tokensPerSecond = 0
        errorBanner = nil
    }
```

- [ ] **Step 4: Run the test and verify it passes**

Cmd-U. Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add llm-visualizer/ViewModels/ChatViewModel.swift \
        llm-visualizerTests/ChatViewModelResetTests.swift
git commit -m "feat(ViewModel): ChatViewModel.reset"
```

---

## Task 12: `StatusBar` View

**Files:**
- Create: `llm-visualizer/Views/StatusBar.swift`

Manual visual check, no automated test for now.

- [ ] **Step 1: Implement `StatusBar`**

Create `llm-visualizer/Views/StatusBar.swift`:

```swift
//
//  StatusBar.swift
//

import SwiftUI

struct StatusBar: View {
    let modelState: ChatViewModel.ModelState
    let isGenerating: Bool
    let tokensPerSecond: Double
    let canReset: Bool
    let onCancel: () -> Void
    let onReset: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusText
                .frame(maxWidth: .infinity, alignment: .leading)

            if isGenerating {
                Button(action: onCancel) {
                    Label("Stop", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.bordered)
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
    }

    @ViewBuilder
    private var statusText: some View {
        switch modelState {
        case .idle:
            Text("Initializing…")
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading model…")
            }
        case .loaded:
            if isGenerating {
                Label(String(format: "Generating · %.1f t/s", tokensPerSecond),
                      systemImage: "circle.fill")
                    .foregroundStyle(.tint)
            } else {
                Text("Ready")
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            HStack(spacing: 6) {
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
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/StatusBar.swift
git commit -m "feat(Views): StatusBar with model state and t/s"
```

---

## Task 13: `MessageView`

**Files:**
- Create: `llm-visualizer/Views/MessageView.swift`

- [ ] **Step 1: Implement `MessageView`**

Create `llm-visualizer/Views/MessageView.swift`:

```swift
//
//  MessageView.swift
//

import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer()
                Text(LocalizedStringKey(message.content))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.tint, in: .rect(cornerRadius: 16))
                    .textSelection(.enabled)
            }
        case .assistant:
            HStack {
                Text(LocalizedStringKey(message.content))
                    .textSelection(.enabled)
                Spacer()
            }
        case .system:
            Label(message.content, systemImage: "desktopcomputer")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/MessageView.swift
git commit -m "feat(Views): MessageView with role-based layout"
```

---

## Task 14: `ConversationView`

**Files:**
- Create: `llm-visualizer/Views/ConversationView.swift`

- [ ] **Step 1: Implement `ConversationView`**

Create `llm-visualizer/Views/ConversationView.swift`:

```swift
//
//  ConversationView.swift
//

import SwiftUI

struct ConversationView: View {
    let messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .defaultScrollAnchor(.bottom)
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/ConversationView.swift
git commit -m "feat(Views): ConversationView scrolling message list"
```

---

## Task 15: `PromptField`

**Files:**
- Create: `llm-visualizer/Views/PromptField.swift`

- [ ] **Step 1: Implement `PromptField`**

Create `llm-visualizer/Views/PromptField.swift`:

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
            TextField("Prompt", text: $prompt, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/PromptField.swift
git commit -m "feat(Views): PromptField with disabled-while-generating"
```

---

## Task 16: `ChatView` (Wiring)

**Files:**
- Create: `llm-visualizer/Views/ChatView.swift`

- [ ] **Step 1: Implement `ChatView`**

Create `llm-visualizer/Views/ChatView.swift`:

```swift
//
//  ChatView.swift
//

import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let banner = viewModel.errorBanner {
                    Text(banner)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.red)
                }

                ConversationView(messages: viewModel.messages)

                Divider()

                StatusBar(
                    modelState: viewModel.modelState,
                    isGenerating: viewModel.isGenerating,
                    tokensPerSecond: viewModel.tokensPerSecond,
                    canReset: viewModel.messages.count > 1,
                    onCancel: { viewModel.cancel() },
                    onReset: { viewModel.reset() },
                    onRetry: {
                        Task { await viewModel.bootstrap() }
                    }
                )

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
            }
            .navigationTitle("LLM Visualizer")
        }
        .task {
            await viewModel.bootstrap()
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add llm-visualizer/Views/ChatView.swift
git commit -m "feat(Views): ChatView wiring all subviews"
```

---

## Task 17: Wire App Entry

**Files:**
- Modify: `llm-visualizer/llm_visualizerApp.swift`

- [ ] **Step 1: Replace the App entry with the wired-up version**

Replace `llm-visualizer/llm_visualizerApp.swift` with:

```swift
//
//  llm_visualizerApp.swift
//  llm-visualizer
//

import SwiftUI

@main
struct llm_visualizerApp: App {
    @State private var viewModel = ChatViewModel(service: LLMService())

    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd-B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual end-to-end test**

Run on a simulator (iPhone 15, iOS 17+):

1. App launches → status bar shows "Loading model…" briefly, then "Ready"
2. Type "Hello" in the prompt field
3. Tap send → assistant message streams token-by-token; status bar shows "Generating · X.X t/s"
4. During generation, the send button is disabled
5. After generation completes, status bar returns to "Ready"
6. Type another message, hit send, then tap "Stop" in the status bar → assistant message ends with `[Cancelled]`
7. Tap the trash icon → only the system message remains
8. Send another message → it works as before
9. Quit and relaunch → model loads from cache faster (or cold-loads; both should work)

- [ ] **Step 4: Commit**

```bash
git add llm-visualizer/llm_visualizerApp.swift
git commit -m "feat(App): wire ChatView with ChatViewModel in App entry"
```

---

## Task 18: UI Tests

**Files:**
- Modify: `llm-visualizerUITests/llm_visualizerUITests.swift`

- [ ] **Step 1: Replace the default UI test with real ones**

Replace `llm-visualizerUITests/llm_visualizerUITests.swift` with:

```swift
//
//  llm_visualizerUITests.swift
//

import XCTest

final class llm_visualizerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyState() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["LLM Visualizer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Prompt"].exists)
    }

    func testStatusBarTransitionsToReady() throws {
        let app = XCUIApplication()
        app.launch()
        // model load can take 5-15s on first run
        let readyPredicate = NSPredicate(format: "label CONTAINS[c] %@", "Ready")
        let ready = app.staticTexts.matching(readyPredicate).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 60))
    }

    func testSendAndReceive() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Prompt"]
        XCTAssertTrue(field.waitForExistence(timeout: 60))
        field.tap()
        field.typeText("Hi")
        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Send")).firstMatch.tap()
        // Wait for assistant message (any non-empty assistant text)
        let assistantPredicate = NSPredicate(format: "label != '' AND label != %@", "Hi")
        let assistant = app.staticTexts.matching(assistantPredicate).element(boundBy: 1)
        XCTAssertTrue(assistant.waitForExistence(timeout: 30))
    }
}
```

- [ ] **Step 2: Run UI tests on a simulator**

In Xcode: select a simulator (iPhone 15, iOS 17+) as the test destination. Cmd-U. Expected: 3 tests pass (model load can take a while on first run).

- [ ] **Step 3: Commit**

```bash
git add llm-visualizerUITests/llm_visualizerUITests.swift
git commit -m "test(UI): add launch, ready, send-and-receive tests"
```

---

## Self-Review Checklist

After executing all tasks, verify:

- [ ] Spec coverage:
  - Bundled local model: Tasks 4 + 7 + 8 + 17
  - Multi-turn text chat: Task 9 (messages list)
  - Streaming generation: Task 9 (chunk append)
  - t/s metrics: Task 9 (info case) + Task 12 (StatusBar display)
  - Cancel: Task 10
  - Reset: Task 11 + Task 12 (trash button)
  - Error states: Task 9 (catch) + Task 12 (StatusBar error)
  - iOS 17.0+: Task 1
  - No model selection UI: confirmed (only one model in ModelConfig)
  - Offline model: confirmed (ModelConfiguration uses directory, no HubApi download)

- [ ] pbxproj IDs are unique (re-run `uuidgen` for each insertion in Tasks 3 and 4)

- [ ] All TDD tasks have a failing test written before implementation

- [ ] Frequent commits: 18 commits total, one per task

- [ ] Manual end-to-end test passed (Task 17, Step 3)

- [ ] UI tests pass on simulator (Task 18)

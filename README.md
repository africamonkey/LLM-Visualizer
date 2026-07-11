# LLM Visualizer

An iOS app that turns an LLM into a tactile teaching toy. Each "level" poses a tiny challenge about how the model thinks; you play by typing sentences and reading the model's probability distribution.

## Levels

| # | Title | Goal |
|---|-------|------|
| 1 | Make AI guess right with its eyes closed | Find a sentence where the model's Top-1 next-token probability is above 90%. |
| 2 | It reads the world in blocks | Find content that fits inside a single tokenizer block; chase 3 stars by packing as many characters as possible into one block. |

## Stack

- SwiftUI + `@Observable`
- MLX (`mlx-swift`, `mlx-swift-lm`) — runs Qwen3-0.6B 4-bit on-device
- Swift Testing

## Run

```bash
xcodebuild -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Test

```bash
DD=~/Library/Developer/Xcode/DerivedData/llm-visualizer-XXXX
xcodebuild test-without-building -project llm-visualizer.xcodeproj -scheme llm-visualizer \
  -destination 'platform=iOS Simulator,id=…' \
  -derivedDataPath "$DD" -only-testing:llm-visualizerTests
```

## Localization

`llm-visualizer/Resources/Localizable.xcstrings` (en + zh-Hans).

## Project layout

```
llm-visualizer/
  Models/        # LevelSession, Level1Session, Level2Session, ProgressStore, LevelError, …
  Services/      # LLMService, MockLLMService
  ViewModels/    # @Observable, @MainActor
  Views/
    Common/      # LevelHeaderView, InspirationButtonsView, EmptyStateView
    LevelShell/  # LevelShellView, PassCelebrationView
    Level1/      # Level1View, ProbabilityBarsView, NarratorLineView
    Level2/      # Level2View (placeholder)
    Onboarding/  # ExampleCardView, OnboardingFlowView
    Loading/     # ModelLoadingView
    Settings/    # SettingsView
    Chat/        # free chat (Level 1 pre-cursor)
llm-visualizerTests/  # Swift Testing
```

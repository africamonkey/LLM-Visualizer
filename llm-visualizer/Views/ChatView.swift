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
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .navigationTitle("LLM Visualizer")
        }
        .task {
            // Skip model load during unit/UI tests — Metal doesn't init in simulator
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                await viewModel.bootstrap()
            }
        }
    }
}
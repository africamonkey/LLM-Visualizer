//
//  Level1View.swift
//

import SwiftUI

struct Level1View: View {

    @Bindable var viewModel: Level1ViewModel
    let session: Level1Session
    let showNarrator: Bool

    @FocusState private var promptFocused: Bool

    private let fragments = InspirationButtonsView.defaultFragments

    var body: some View {
        VStack(spacing: 0) {
            if let banner = viewModel.errorBanner {
                Text(banner)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .transition(.opacity)
            }
            inputSection
            if viewModel.topCandidates.isEmpty {
                EmptyStateView(
                    message: String(
                        localized: "level1.emptyState",
                        defaultValue: "Type a sentence above — the bars below show how sure the AI is about its next word."
                    )
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            } else {
                ProbabilityBarsView(
                    candidates: viewModel.topCandidates,
                    isPassed: viewModel.state == .passed
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            if showNarrator {
                NarratorLineView(sentiment: viewModel.currentSentiment)
                    .padding(.bottom, 4)
            }
            Spacer(minLength: 8)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorBanner)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .passed {
                promptFocused = false
                session.evaluate()
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Your input", defaultValue: "Your input"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(
                    String(localized: "Type your sentence…", defaultValue: "Type your sentence…"),
                    text: $viewModel.prompt
                )
                .focused($promptFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                )
                .onChange(of: viewModel.prompt) { _, newValue in
                    if newValue.count > 200 {
                        viewModel.prompt = String(newValue.prefix(200))
                    }
                }
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.accentColor))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.accentColor))
                    }
                }
                .buttonStyle(.plain)
                .disabled(
                    viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isLoading
                )
                .accessibilityLabel(String(
                    localized: "level1.submit",
                    defaultValue: "Submit"
                ))
            }
            InspirationButtonsView(fragments: fragments) { fragment in
                let trimmed = viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    viewModel.prompt = fragment
                } else {
                    viewModel.prompt = trimmed + fragment
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    promptFocused = false
                } label: {
                    Text(String(
                        localized: "keyboard.done",
                        defaultValue: "Done"
                    ))
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

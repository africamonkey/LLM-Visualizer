//
//  Level1View.swift
//

import SwiftUI

struct Level1View: View {

    @Bindable var viewModel: Level1ViewModel
    let session: Level1Session
    let showNarrator: Bool
    let onGoToNextLevel: (() -> Void)?

    @FocusState private var promptFocused: Bool

    private let fragments = InspirationButtonsView.defaultFragments

    private var canSubmit: Bool {
        !viewModel.prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
            && !viewModel.isLoading
    }

    init(
        viewModel: Level1ViewModel,
        session: Level1Session,
        showNarrator: Bool,
        onGoToNextLevel: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.session = session
        self.showNarrator = showNarrator
        self.onGoToNextLevel = onGoToNextLevel
    }

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
                HStack(spacing: 12) {
                    CounterCell(
                        label: String(localized: "level1.counter.top1", defaultValue: "top-1"),
                        value: Int((viewModel.topCandidates.first?.probability ?? 0) * 100)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                ProbabilityBarsView(
                    candidates: viewModel.topCandidates,
                    isPassed: viewModel.currentTop1IsPass
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            if showNarrator {
                NarratorLineView(sentiment: viewModel.currentSentiment)
                    .padding(.bottom, 4)
            }
            if viewModel.currentTop1IsPass {
                Text(String(
                    localized: "level1.statePill",
                    defaultValue: "✨ passed"
                ))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.18)))
                .foregroundStyle(Color.green)
                .padding(.bottom, 4)
                .transition(.opacity)
            }
            Spacer(minLength: 8)
            if session.isComplete, let onGoToNextLevel {
                nextLevelButton(action: onGoToNextLevel)
            }
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

    private func nextLevelButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(String(
                localized: "level.nextLevel",
                defaultValue: "Next level →"
            ))
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                            .background(Circle().fill(canSubmit ? Color.accentColor : Color.gray.opacity(0.4)))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityLabel(String(
                    localized: "level1.submit",
                    defaultValue: "Submit"
                ))
            }
            InspirationButtonsView(fragments: fragments) { fragment in
                viewModel.prompt = fragment
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
                    Image(systemName: "keyboard.chevron.compact.down.fill")
                        .imageScale(.large)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .padding(.bottom, 4)
                .accessibilityLabel(String(
                    localized: "keyboard.done",
                    defaultValue: "Done"
                ))
            }
        }
    }
}

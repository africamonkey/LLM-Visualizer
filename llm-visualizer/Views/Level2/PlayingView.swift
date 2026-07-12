//
//  PlayingView.swift
//

import SwiftUI

struct PlayingView: View {

    @Bindable var viewModel: Level2ViewModel

    private let commonWords = ["我", "你", "我们", "好"]

    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            inputSection
            countersSection
            blocksSection
            HintBanner(
                tier: viewModel.hintTier,
                onApplyExample: { viewModel.applyHint2Example() }
            )
            Spacer()
            submitButton
        }
        .padding(16)
        .overlay(alignment: .top) {
            if let banner = viewModel.errorBanner {
                Text(banner)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorBanner)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "level2.input.caption", defaultValue: "Your input"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(
                    String(
                        localized: "level2.input.placeholder",
                        defaultValue: "Type here…"
                    ),
                    text: $viewModel.rawText
                )
                .focused($promptFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                )
                // B7: cap input length so a paste of a huge string can't lag the UI.
                .onChange(of: viewModel.rawText) { _, newValue in
                    if newValue.count > 200 {
                        viewModel.rawText = String(newValue.prefix(200))
                    }
                }
                .onSubmit { viewModel.submit() }
            }
            HStack(spacing: 6) {
                ForEach(commonWords, id: \.self) { w in
                    Button {
                        viewModel.rawText = w
                    } label: {
                        Text(w)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var countersSection: some View {
        HStack(spacing: 12) {
            counterCell(
                label: String(localized: "level2.counters.chars", defaultValue: "characters"),
                value: viewModel.rawText.count
            )
            counterCell(
                label: String(localized: "level2.counters.blocks", defaultValue: "blocks"),
                value: viewModel.tokens.count
            )
            if viewModel.isPassing {
                Text(String(localized: "level2.counters.passed", defaultValue: "✨ passed"))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.green.opacity(0.18)))
                    .foregroundStyle(Color.green)
                    .transition(.opacity)
            }
        }
    }

    private func counterCell(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var blocksSection: some View {
        TokenBlocksView(tokens: viewModel.tokens)
            .padding(.vertical, 8)
    }

    /// B1: explicit Submit button. Without this, every keystroke would fire
    /// pass detection and instantly yank the user to PassedView on the first
    /// single-token character.
    private var submitButton: some View {
        Button {
            promptFocused = false
            viewModel.submit()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "paperplane.fill")
                    .font(.body.weight(.semibold))
                Text(String(localized: "level2.submit", defaultValue: "Submit"))
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(canSubmit ? Color.accentColor : Color.gray.opacity(0.4))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        !viewModel.rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
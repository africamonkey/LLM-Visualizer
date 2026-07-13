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
                // B1: submit button lives inline to the right of the TextField,
                // matching Level 1's pattern. Without this, pass detection
                // would fire on every keystroke (B1) — the button gates it.
                Button {
                    promptFocused = false
                    viewModel.submit()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(canSubmit ? Color.accentColor : Color.gray.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityLabel(String(
                    localized: "level2.submit",
                    defaultValue: "Submit"
                ))
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
            CounterCell(
                label: String(localized: "level2.counters.chars", defaultValue: "characters"),
                value: viewModel.rawText.count
            )
            CounterCell(
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

    private var blocksSection: some View {
        TokenBlocksView(tokens: viewModel.tokens)
            .padding(.vertical, 8)
    }

    private var canSubmit: Bool {
        !viewModel.rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
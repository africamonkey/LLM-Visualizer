//
//  PlayingView.swift
//

import SwiftUI

struct PlayingView: View {

    @Bindable var viewModel: Level2ViewModel

    private let commonWords = ["我", "你", "我们", "好"]

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
            TextField(
                String(
                    localized: "level2.input.placeholder",
                    defaultValue: "Type here…"
                ),
                text: $viewModel.rawText
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
            )
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
}

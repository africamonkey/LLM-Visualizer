//
//  FreePlayView.swift
//

import SwiftUI

struct FreePlayView: View {

    @Bindable var viewModel: Level1ViewModel
    let playsSoFar: Int
    let onUserSubmitted: () -> Void
    let onTapReady: () -> Void

    private let fragments = InspirationButtonsView.defaultFragments

    private var showNarrator: Bool { playsSoFar >= 2 }
    private var narrator: NarratorLineView.Sentiment {
        NarratorLineView.sentiment(for: viewModel.topCandidates.first?.probability ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            inputSection
            ProbabilityBarsView(candidates: viewModel.topCandidates)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            if showNarrator {
                NarratorLineView(sentiment: narrator)
                    .padding(.bottom, 4)
            }
            Spacer(minLength: 8)
            footer
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(
                    localized: "Try another sentence, see how AI guesses",
                    defaultValue: "Try another sentence, see how AI guesses"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Spacer()
                if showNarrator {
                    Button(action: onTapReady) {
                        Text(String(
                            localized: "I'm ready",
                            defaultValue: "I'm ready"
                        ))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                TextField(
                    String(localized: "Type your sentence…", defaultValue: "Type your sentence…"),
                    text: $viewModel.prompt
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                )
                Button {
                    Task {
                        await viewModel.submit()
                        if !viewModel.topCandidates.isEmpty { onUserSubmitted() }
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            InspirationButtonsView(fragments: fragments) { fragment in
                viewModel.prompt = fragment
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var footer: some View {
        HStack {
            let playsFormat = String(
                localized: "Played %d times",
                defaultValue: "Played %d times"
            )
            Text(String(format: playsFormat, playsSoFar))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            let bestFormat = String(
                localized: "Best record %d%%",
                defaultValue: "Best record %d%%"
            )
            Text(String(format: bestFormat, Int((viewModel.bestSoFar * 100).rounded())))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
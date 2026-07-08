//
//  Level1View.swift
//

import SwiftUI

struct Level1View: View {

    @Bindable var viewModel: Level1ViewModel
    let session: Level1Session
    let showNarrator: Bool

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
            ProbabilityBarsView(
                candidates: viewModel.topCandidates,
                isPassed: viewModel.state == .passed
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            if showNarrator {
                NarratorLineView(
                    sentiment: viewModel.state == .passed
                        ? .passed
                        : NarratorLineView.sentiment(
                            for: viewModel.topCandidates.first?.probability ?? 0
                        )
                )
                .padding(.bottom, 4)
            }
            Spacer(minLength: 8)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorBanner)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .passed {
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
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                )
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
                viewModel.prompt = fragment
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }
}

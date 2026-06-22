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

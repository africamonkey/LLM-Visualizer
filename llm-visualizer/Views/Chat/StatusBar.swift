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

    @State private var pulseOn = false

    var body: some View {
        HStack(spacing: 12) {
            statusText
                .frame(maxWidth: .infinity, alignment: .leading)

            if isGenerating {
                Button(action: onCancel) {
                    Label("Stop", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
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
        .onAppear { pulseOn = (modelState == .loading) }
        .onChange(of: modelState) { _, new in pulseOn = (new == .loading) }
    }

    @ViewBuilder
    private var statusText: some View {
        switch modelState {
        case .idle:
            HStack(spacing: 6) {
                statusDot(modelState, isGenerating: false)
                Text("Initializing…")
            }
        case .loading:
            HStack(spacing: 6) {
                statusDot(modelState, isGenerating: false)
                ProgressView().controlSize(.small)
                Text("Loading model…")
            }
        case .loaded:
            if isGenerating {
                HStack(spacing: 6) {
                    statusDot(modelState, isGenerating: true)
                    let format = String(
                        localized: "Generating · %.1f t/s",
                        defaultValue: "Generating · %.1f t/s"
                    )
                    Label(String(format: format, tokensPerSecond),
                          systemImage: "circle.fill")
                        .foregroundStyle(.tint)
                }
            } else {
                HStack(spacing: 6) {
                    statusDot(modelState, isGenerating: false)
                    Text("Ready")
                        .foregroundStyle(.secondary)
                }
            }
        case .error(let message):
            HStack(spacing: 6) {
                statusDot(modelState, isGenerating: false)
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

    @ViewBuilder
    private func statusDot(_ state: ChatViewModel.ModelState,
                            isGenerating: Bool) -> some View {
        let color: Color = {
            switch state {
            case .idle:    return .gray
            case .loading: return .orange
            case .loaded:
                return isGenerating ? .accentColor : .green
            case .error:   return .red
            }
        }()
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
            .opacity(pulseOn ? 0.45 : 1.0)
            .animation(
                pulseOn
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : nil,
                value: pulseOn
            )
    }
}

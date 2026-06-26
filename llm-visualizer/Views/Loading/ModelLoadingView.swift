//
//  ModelLoadingView.swift
//

import SwiftUI

struct ModelLoadingView: View {

    let state: AppShellViewModel.State
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            logo
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var logo: some View {
        Image(systemName: "circle.hexagongrid.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .foregroundStyle(.tint)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            Text("Loading model…")
                .font(.body)
                .foregroundStyle(.secondary)
            ProgressView()
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        case .ready:
            EmptyView()  // unreachable — AppRootView routes around
        }
    }
}

//
//  TokenBlocksView.swift
//

import SwiftUI

struct TokenBlocksView: View {
    enum Style { case standard, compact }

    let tokens: [TokenPiece]
    var style: Style = .standard

    var body: some View {
        if tokens.isEmpty {
            EmptyView()
        } else if tokens.count == 1 && style == .standard {
            singleBlockExplosion(token: tokens[0])
        } else {
            HStack(alignment: .center, spacing: style == .standard ? 8 : 4) {
                ForEach(tokens) { t in
                    blockTile(for: t)
                }
            }
        }
    }

    @ViewBuilder
    private func blockTile(for t: TokenPiece) -> some View {
        switch style {
        case .standard:
            Text(t.text)
                .font(.body.monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(blockColor(for: t))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
        case .compact:
            Text(t.text)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(blockColor(for: t))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func singleBlockExplosion(token: TokenPiece) -> some View {
        Text(token.text)
            .font(.title2.monospaced().weight(.bold))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.84, blue: 0.04),
                        Color(red: 1.00, green: 0.62, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white, lineWidth: 4)
                    .padding(-4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.accentColor, lineWidth: 4)
                    .padding(-8)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .scaleEffect(1.0)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func blockColor(for piece: TokenPiece) -> Color {
        // Deterministic hash → palette index. 8 colors is enough for a row.
        let palette: [Color] = [
            Color(red: 1.00, green: 0.84, blue: 0.04),  // yellow
            Color(red: 0.20, green: 0.78, blue: 0.35),  // green
            Color(red: 1.00, green: 0.27, blue: 0.23),  // red
            Color(red: 0.04, green: 0.52, blue: 1.00),  // blue
            Color(red: 0.34, green: 0.78, blue: 0.98),  // sky
            Color(red: 0.75, green: 0.35, blue: 0.95),  // purple
            Color(red: 1.00, green: 0.45, blue: 0.70),  // pink
            Color(red: 0.40, green: 0.85, blue: 0.55),  // mint
        ]
        let idx = abs(piece.id.hashValue) % palette.count
        return palette[idx]
    }
}

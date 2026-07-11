//
//  DemoView.swift
//

import SwiftUI

struct DemoView: View {

    @Bindable var viewModel: Level2ViewModel
    let onContinue: () -> Void

    @State private var hasTyped: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(
                localized: "level2.demo.prompt",
                defaultValue: "Type a few characters and see how AI chops them up."
            ))
            .font(.body.weight(.medium))

            inputRow

            inspirationRow

            TokenBlocksView(tokens: viewModel.tokens)
                .padding(.vertical, 8)

            revealText
                .padding(.top, 8)

            Spacer()

            Button(action: onContinue) {
                Text(String(
                    localized: "level2.demo.cta",
                    defaultValue: "I'll try"
                ))
                .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(hasTyped ? Color.accentColor : Color.gray.opacity(0.4)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!hasTyped)
        }
        .padding(20)
        .onAppear {
            if !hasTyped {
                viewModel.rawText = "我爱北京"
                hasTyped = true
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
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
            .onChange(of: viewModel.rawText) { _, _ in hasTyped = true }
        }
    }

    private var inspirationRow: some View {
        HStack(spacing: 8) {
            chip("我爱北京")
            chip("unbelievable")
            chip("\u{1F327}\u{FE0F}")
        }
    }

    private func chip(_ text: String) -> some View {
        Button {
            viewModel.rawText = text
            hasTyped = true
        } label: {
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.accentColor.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private var revealText: some View {
        Text(String(
            localized: "level2.demo.reveal",
            defaultValue: "See? AI doesn't read character by character. It chops text into blocks — those blocks are called tokens. AI only knows tokens."
        ))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
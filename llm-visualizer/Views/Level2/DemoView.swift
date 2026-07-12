//
//  DemoView.swift
//

import SwiftUI

struct DemoView: View {

    @Bindable var viewModel: Level2ViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(
                localized: "level2.demo.prompt",
                defaultValue: "Try typing anything. See how AI chops it into blocks."
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
                    defaultValue: "I've got it — show me the challenge"
                ))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .onAppear {
            // B10: always force the pre-fill on entry. Don't gate on hasTyped,
            // because re-entering DemoView (e.g., via Settings → Levels) should
            // still show the example, not whatever rawText was left over.
            viewModel.rawText = "我爱北京"
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
        }
    }

    private var inspirationRow: some View {
        HStack(spacing: 8) {
            chip("我爱北京")
            chip("unbelievable")
            chip("asdfqwerty")  // B5: explicit gibberish, not a weather emoji
        }
    }

    private func chip(_ text: String) -> some View {
        Button {
            viewModel.rawText = text
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
        // B8: hint at the discovery the user should make in the playing phase.
        Text(String(
            localized: "level2.demo.reveal",
            defaultValue: "Those blocks are called tokens — that's how AI reads text, not character by character. Try the challenge: can you pack something into a single block?"
        ))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
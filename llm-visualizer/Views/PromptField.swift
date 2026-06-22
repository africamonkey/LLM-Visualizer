//
//  PromptField.swift
//

import SwiftUI

struct PromptField: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Prompt", text: $prompt, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}
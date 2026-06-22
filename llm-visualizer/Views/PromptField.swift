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
            TextField("Ask anything…", text: $prompt, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }
                .modifier(PromptFieldBackground())

            Button(action: onSend) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(PromptSendButtonStyle())
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityLabel("Send")
        }
    }
}
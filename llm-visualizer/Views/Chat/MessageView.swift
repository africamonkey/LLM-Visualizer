//
//  MessageView.swift
//

import SwiftUI

struct MessageView: View {
    private let userBubbleColor = Color(red: 0.357, green: 0.694, blue: 1.0)

    let message: Message

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer()
                Text(LocalizedStringKey(message.content))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(userBubbleColor, in: .rect(cornerRadius: 16))
                    .textSelection(.enabled)
            }
        case .assistant:
            let parsed = ThinkingParser.parse(message.content)
            VStack(alignment: .leading, spacing: 8) {
                if let thinking = parsed.thinking {
                    ThinkingBlock(content: thinking)
                }
                if !parsed.answer.isEmpty {
                    Text(LocalizedStringKey(parsed.answer))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Color(.secondarySystemBackground),
                            in: .rect(cornerRadius: 16)
                        )
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .system:
            Label(message.content, systemImage: "desktopcomputer")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
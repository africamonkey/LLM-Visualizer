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
            HStack {
                Text(LocalizedStringKey(message.content))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
                    .textSelection(.enabled)
                Spacer()
            }
        case .system:
            Label(message.content, systemImage: "desktopcomputer")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
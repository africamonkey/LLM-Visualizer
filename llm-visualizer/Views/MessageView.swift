//
//  MessageView.swift
//

import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer()
                Text(LocalizedStringKey(message.content))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.tint, in: .rect(cornerRadius: 16))
                    .textSelection(.enabled)
            }
        case .assistant:
            HStack {
                Text(LocalizedStringKey(message.content))
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
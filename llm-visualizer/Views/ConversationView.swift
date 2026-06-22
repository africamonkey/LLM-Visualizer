//
//  ConversationView.swift
//

import SwiftUI

struct ConversationView: View {
    let messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .defaultScrollAnchor(.bottom)
    }
}
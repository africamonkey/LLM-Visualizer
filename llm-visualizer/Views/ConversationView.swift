//
//  ConversationView.swift
//

import SwiftUI

struct ConversationView: View {
    let messages: [Message]
    @State private var isAtBottom: Bool = true

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .onAppear {
                                    if message.id == messages.last?.id {
                                        isAtBottom = true
                                    }
                                }
                                .onDisappear {
                                    if message.id == messages.last?.id {
                                        isAtBottom = false
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { _, _ in
                    // New message appended (user just sent) — force scroll
                    if let last = messages.last {
                        isAtBottom = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages.last?.content) { _, _ in
                    // Last message content changed (streaming) — follow if at bottom
                    guard isAtBottom, let last = messages.last else { return }
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }

                if !isAtBottom {
                    JumpToBottomButton {
                        if let last = messages.last {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        isAtBottom = true
                    }
                    .padding(.bottom, 16)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

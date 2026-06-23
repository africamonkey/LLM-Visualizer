//
//  ConversationView.swift
//

import SwiftUI

struct ConversationView: View {
    let messages: [Message]
    @State private var isAtBottom: Bool = true
    @State private var suppressDisappearUntilAppear: Bool = false
    @State private var suppressResetTask: Task<Void, Never>?

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
                                        suppressDisappearUntilAppear = false
                                        suppressResetTask?.cancel()
                                    }
                                }
                                .onDisappear {
                                    if message.id == messages.last?.id
                                        && !suppressDisappearUntilAppear {
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
                            suppressDisappearUntilAppear = true
                            isAtBottom = true
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                            // Failsafe: if last message never re-appears
                            // (e.g. short list, no last message), clear the
                            // flag after 5s so isAtBottom can update again.
                            suppressResetTask?.cancel()
                            suppressResetTask = Task { @MainActor in
                                try? await Task.sleep(for: .seconds(5))
                                guard !Task.isCancelled else { return }
                                suppressDisappearUntilAppear = false
                            }
                        }
                    }
                    .padding(.bottom, 16)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

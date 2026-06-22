//
//  Message.swift
//

import Foundation

nonisolated struct Message: Identifiable, Sendable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    init(role: Role, content: String, id: UUID = UUID(), timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    enum Role: Sendable, Equatable {
        case user
        case assistant
        case system
    }
}

extension Message {
    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }

    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
}
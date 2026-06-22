//
//  MessageTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

struct MessageTests {

    @Test func userFactorySetsRoleAndContent() {
        let message = Message.user("hi")
        #expect(message.role == .user)
        #expect(message.content == "hi")
    }

    @Test func assistantFactorySetsRoleAndContent() {
        let message = Message.assistant("hello")
        #expect(message.role == .assistant)
        #expect(message.content == "hello")
    }

    @Test func systemFactorySetsRoleAndContent() {
        let message = Message.system("you are helpful")
        #expect(message.role == .system)
        #expect(message.content == "you are helpful")
    }

    @Test func idsAreUnique() {
        let a = Message.user("a")
        let b = Message.user("b")
        #expect(a.id != b.id)
    }

    @Test func timestampIsRecent() {
        let before = Date()
        let message = Message.user("x")
        let after = Date()
        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }
}
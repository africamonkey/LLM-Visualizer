//
//  LevelErrorTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct LevelErrorTests {

    @Test func modelNotReadyMapsToFriendlyMessage() {
        let raw = "Metal device not found"
        let humanized = LevelError.humanize(NSError(
            domain: "MLX", code: 0,
            userInfo: [NSLocalizedDescriptionKey: raw]
        ))
        #expect(!humanized.isEmpty)
        #expect(humanized != raw)  // humanizer transforms the message
    }

    @Test func emptyPromptMapsToFriendlyMessage() {
        let raw = "empty input"
        let humanized = LevelError.humanize(NSError(
            domain: "Prompt", code: 1,
            userInfo: [NSLocalizedDescriptionKey: raw]
        ))
        #expect(!humanized.isEmpty)
        #expect(humanized != raw)
    }

    @Test func unknownErrorFallsBackToGeneric() {
        let raw = "out of cheese"
        let humanized = LevelError.humanize(NSError(
            domain: "Other", code: 99,
            userInfo: [NSLocalizedDescriptionKey: raw]
        ))
        #expect(!humanized.isEmpty)
        #expect(humanized != raw)
    }

    @Test func humanizeNeverReturnsEmpty() {
        let e = LevelError.humanize(NSError(domain: "x", code: 0, userInfo: nil))
        #expect(!e.isEmpty)
    }

    @Test func metalErrorsRouteDifferentlyFromGeneric() {
        let metalError = NSError(
            domain: "MLX", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Metal device not found"]
        )
        let genericError = NSError(
            domain: "x", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "random failure"]
        )
        #expect(
            LevelError.humanize(metalError) != LevelError.humanize(genericError)
        )
    }
}

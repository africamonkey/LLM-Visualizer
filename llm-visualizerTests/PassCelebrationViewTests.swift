//
//  PassCelebrationViewTests.swift
//

import Foundation
import Testing
import SwiftUI
@testable import llm_visualizer

@MainActor
struct PassCelebrationViewTests {

    @Test func newRecordParamCompilesForTrue() {
        let view = PassCelebrationView(
            echoedPrompt: "x",
            topCandidate: TokenCandidate(id: 1, text: "y", probability: 0.95),
            isNewRecord: true,
            onContinue: {},
            onGoToNextLevel: {}
        )
        _ = view.body
    }

    @Test func newRecordParamCompilesForFalse() {
        let view = PassCelebrationView(
            echoedPrompt: "x",
            topCandidate: TokenCandidate(id: 1, text: "y", probability: 0.95),
            isNewRecord: false,
            onContinue: {},
            onGoToNextLevel: nil
        )
        _ = view.body
    }

    @Test func newRecordDefaultsToFalseWhenNotProvided() {
        let view = PassCelebrationView(
            echoedPrompt: "x",
            topCandidate: nil,
            onContinue: {},
            onGoToNextLevel: nil
        )
        _ = view.body
    }
}
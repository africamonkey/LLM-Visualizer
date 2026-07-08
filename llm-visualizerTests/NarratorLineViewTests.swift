//
//  NarratorLineViewTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@MainActor
struct NarratorLineViewTests {

    @Test func highThresholdMapsToHigh() {
        #expect(NarratorLineView.sentiment(for: 0.95) == .high)
        #expect(NarratorLineView.sentiment(for: 0.70) == .high)
    }

    @Test func midRangeMapsToMedium() {
        #expect(NarratorLineView.sentiment(for: 0.50) == .medium)
        #expect(NarratorLineView.sentiment(for: 0.40) == .medium)
    }

    @Test func lowRangeMapsToLow() {
        #expect(NarratorLineView.sentiment(for: 0.39) == .low)
        #expect(NarratorLineView.sentiment(for: 0.0) == .low)
    }

    @Test func passedTextIsLongerThanBase() {
        let base = NarratorLineView.Sentiment.high.text
        let wrapped = NarratorLineView.Sentiment.passed(current: .high).text
        #expect(wrapped.count > base.count)
    }

    @Test func passedTextContainsBaseText() {
        let base = NarratorLineView.Sentiment.low.text
        let wrapped = NarratorLineView.Sentiment.passed(current: .low).text
        #expect(wrapped.contains(base))
    }

    @Test func passedTextEndsWithBaseText() {
        let base = NarratorLineView.Sentiment.medium.text
        let wrapped = NarratorLineView.Sentiment.passed(current: .medium).text
        #expect(wrapped.hasSuffix(base))
    }
}

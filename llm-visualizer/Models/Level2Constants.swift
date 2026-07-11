//
//  Level2Constants.swift
//

import Foundation

/// Star and hint-2 calibration values, populated by
/// `scripts/probe-tokenizer.swift` (see spec §6) before the implementation
/// commit lands. The threshold tests use `>=` comparisons so the precise
/// values can drift without breaking tests.
enum Level2Constants {

    /// Char count that awards 1 star.
    static let star1Threshold: Int = 3

    /// Char count that awards 2 stars.
    static let star2Threshold: Int = 5

    /// Char count that awards 3 stars.
    static let star3Threshold: Int = 7

    /// Threshold for `attemptCount` to escalate `hintTier` to `.direction`.
    static let hint1AttemptThreshold: Int = 5

    /// Threshold for `attemptCount` to escalate `hintTier` to `.example`
    /// (autofills `rawText`).
    static let hint2AttemptThreshold: Int = 10

    /// The hint-tier-2 example word. Initial value is "我" (always single
    /// token for Qwen3). Re-calibrate via the probe if needed.
    static let hint2ExampleText: String = "我"

    /// Pass condition: token count must equal this.
    static let passTokenCount: Int = 1

    /// Minimum non-whitespace grapheme count to qualify as a pass
    /// (excludes "all whitespace" type exploits).
    static let passMinNonWhitespace: Int = 1
}

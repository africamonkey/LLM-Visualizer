//
//  ThinkingParser.swift
//

import Foundation

enum ThinkingParser {
    static func parse(_ raw: String) -> (thinking: String?, answer: String) {
        if let endRange = raw.range(of: "</think>") {
            let before = raw[..<endRange.lowerBound]
            let after  = raw[endRange.upperBound...]
            let thinking = before
                .replacingOccurrences(of: "<think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = after.trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking.isEmpty ? nil : thinking, answer)
        }
        if raw.contains("<think>") {
            let thinking = raw
                .replacingOccurrences(of: "<think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking.isEmpty ? nil : thinking, "")
        }
        return (nil, raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
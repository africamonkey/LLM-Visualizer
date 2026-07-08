//
//  LevelError.swift
//

import Foundation

enum LevelError {
    /// Maps raw model-layer errors to user-facing copy. Returns localized text;
    /// never returns an empty string.
    static func humanize(_ error: Error) -> String {
        let raw = (error as NSError).localizedDescription.lowercased()
        if raw.contains("metal") || raw.contains("device not found") {
            return String(
                localized: "error.model.loading",
                defaultValue: "Model is still loading. Please wait a moment."
            )
        }
        if raw.contains("empty") || raw.contains("invalid input") {
            return String(
                localized: "error.prompt.empty",
                defaultValue: "Please type a sentence first."
            )
        }
        return String(
            localized: "error.generic",
            defaultValue: "Something went wrong. Please try again."
        )
    }
}

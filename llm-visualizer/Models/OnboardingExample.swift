//
//  OnboardingExample.swift
//

import Foundation

struct OnboardingExample: Equatable, Sendable {
    let prompt: String
    let candidates: [TokenCandidate]
}

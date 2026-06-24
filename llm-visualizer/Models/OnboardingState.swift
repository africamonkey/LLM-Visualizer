//
//  OnboardingState.swift
//

import Foundation

enum OnboardingPhase: Equatable {
    case opening
    case freePlay(playsSoFar: Int)
    case challengeIntro
}

//
//  ChallengeIntroView.swift
//

import SwiftUI

struct ChallengeIntroView: View {

    let bestSoFar: Double
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack {
                Spacer()
                ChallengeIntroCard(bestSoFar: bestSoFar, onAccept: onAccept)
                Spacer()
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    ChallengeIntroView(bestSoFar: 0.68, onAccept: {})
}
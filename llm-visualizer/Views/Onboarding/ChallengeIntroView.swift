//
//  ChallengeIntroView.swift
//

import SwiftUI

struct ChallengeIntroView: View {

    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack {
                Spacer()
                ChallengeIntroCard(onAccept: onAccept)
                Spacer()
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    ChallengeIntroView(onAccept: {})
}

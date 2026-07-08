//
//  NarratorLineView.swift
//

import SwiftUI

struct NarratorLineView: View {

    indirect enum Sentiment: Equatable {
        case high     // ≥ 0.70
        case medium   // 0.40 … 0.70
        case low      // < 0.40
        case passed(current: Sentiment)   // user has cleared the level; show "you passed" + current vibe

        var text: String {
            switch self {
            case .high:
                return String(localized: "narrator.high", defaultValue: "This time AI seems pretty sure.")
            case .medium:
                return String(localized: "narrator.medium", defaultValue: "This time AI is a bit unsure.")
            case .low:
                return String(localized: "narrator.low",
                              defaultValue: "This time AI is very hesitant — several words have similar scores.")
            case .passed(let current):
                let prefix = String(
                    localized: "narrator.passedPrefix",
                    defaultValue: "You passed — "
                )
                return prefix + current.text
            }
        }
    }

    let sentiment: Sentiment

    var body: some View {
        Text(sentiment.text)
            .font(.footnote.italic())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    static func sentiment(for top1Probability: Double) -> Sentiment {
        if top1Probability >= 0.70 { return .high }
        if top1Probability >= 0.40 { return .medium }
        return .low
    }
}

#Preview {
    VStack {
        NarratorLineView(sentiment: .high)
        NarratorLineView(sentiment: .medium)
        NarratorLineView(sentiment: .low)
        NarratorLineView(sentiment: .passed(current: .high))
        NarratorLineView(sentiment: .passed(current: .low))
    }
    .padding()
}

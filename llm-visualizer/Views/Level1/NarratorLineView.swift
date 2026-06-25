//
//  NarratorLineView.swift
//

import SwiftUI

struct NarratorLineView: View {

    enum Sentiment: Equatable {
        case high     // ≥ 0.70
        case medium   // 0.40 … 0.70
        case low      // < 0.40
        case passed   // top-1 over the pass threshold (post-pass only)

        var text: String {
            switch self {
            case .high:
                return String(localized: "This time AI seems pretty sure.", defaultValue: "This time AI seems pretty sure.")
            case .medium:
                return String(localized: "This time AI is a bit unsure.", defaultValue: "This time AI is a bit unsure.")
            case .low:
                return String(localized: "This time AI is very hesitant — several words have similar scores.",
                              defaultValue: "This time AI is very hesitant — several words have similar scores.")
            case .passed:
                return String(localized: "This time AI almost guessed right with its eyes closed!",
                              defaultValue: "This time AI almost guessed right with its eyes closed!")
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
        NarratorLineView(sentiment: .passed)
    }
    .padding()
}

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
                return String(localized: "这次 AI 挺确定的。", defaultValue: "这次 AI 挺确定的。")
            case .medium:
                return String(localized: "这次 AI 有点拿不准。", defaultValue: "这次 AI 有点拿不准。")
            case .low:
                return String(localized: "这次 AI 很犹豫，几个词分数差不多。",
                              defaultValue: "这次 AI 很犹豫，几个词分数差不多。")
            case .passed:
                return String(localized: "这次 AI 几乎闭眼都猜对了！",
                              defaultValue: "这次 AI 几乎闭眼都猜对了！")
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

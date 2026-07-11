//
//  HintBanner.swift
//

import SwiftUI

struct HintBanner: View {

    let tier: Level2ViewModel.HintTier
    let onApplyExample: () -> Void

    var body: some View {
        if let content = content {
            content
        }
    }

    @ViewBuilder
    private var content: (some View)? {
        switch tier {
        case .none:
            EmptyView()
        case .direction:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Color.accentColor)
                Text(String(
                    localized: "level2.hint.tier1",
                    defaultValue: "Try a word AI sees a lot — common words are more likely to fit in one block."
                ))
                .font(.subheadline)
                .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.10))
            )
        case .example:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(String(
                        localized: "level2.hint.tier2",
                        defaultValue: "Look — AI packs this whole word into a single block. The field is now filled with an example."
                    ))
                    .font(.subheadline)
                    Spacer()
                }
                Button(action: onApplyExample) {
                    Text(String(
                        localized: "level2.hint.tier2.button",
                        defaultValue: "Try this word"
                    ))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.18))
            )
        }
    }
}

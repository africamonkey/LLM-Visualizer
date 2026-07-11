//
//  PassedView.swift
//

import SwiftUI

struct PassedView: View {

    @Bindable var viewModel: Level2ViewModel
    let onContinueGrinding: () -> Void
    let onGoToLevel3: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(String(localized: "level2.passed.title", defaultValue: "You did it"))
                    .font(.title.weight(.bold))

                summaryCard

                starDisplay

                recap

                Divider()

                bridgeSection

                HStack(spacing: 12) {
                    Button(action: onContinueGrinding) {
                        Text(String(
                            localized: "level2.passed.continueGrinding",
                            defaultValue: "Try again for more stars"
                        ))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: onGoToLevel3) {
                        Text(String(
                            localized: "level2.passed.goToLevel3",
                            defaultValue: "Level 3 →"
                        ))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.rawText.isEmpty {
                Text(viewModel.rawText)
                    .font(.body.monospaced())
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                    )
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(viewModel.bestCharCount) ")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                Text(String(
                    localized: "level2.passed.summary.intoBlocks",
                    defaultValue: "characters packed into 1 block"
                ))
                .font(.subheadline)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var starDisplay: some View {
        HStack(spacing: 12) {
            ForEach(0..<3) { i in
                Image(systemName: i < viewModel.earnedStars ? "star.fill" : "star")
                    .font(.system(size: 36))
                    .foregroundStyle(i < viewModel.earnedStars ? Color.yellow : Color.gray.opacity(0.4))
            }
        }
    }

    private var recap: some View {
        Text(String(
            localized: "level2.passed.recap",
            defaultValue: "You just discovered how AI reads - no characters, only blocks. The more familiar something is, the bigger the block."
        ))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }

    private var bridgeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Level 3")
                .font(.caption.weight(.bold).smallCaps())
                .foregroundStyle(Color.accentColor)
            Text(String(
                localized: "level2.passed.bridge",
                defaultValue: "Now you know how AI reads. But here's a strange thing — give it the same sentence twice, and it picks different words each time. There's a knob behind that."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
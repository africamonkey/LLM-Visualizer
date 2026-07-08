//
//  InspirationButtonsView.swift
//

import SwiftUI

struct InspirationButtonsView: View {

    static let defaultFragments: [String] = [
        String(localized: "inspiration.fragment.eat", defaultValue: "I like to eat"),
        String(localized: "inspiration.fragment.tomorrow", defaultValue: "Tomorrow I will go to"),
        String(localized: "inspiration.fragment.life", defaultValue: "The most important thing in life is"),
        String(localized: "inspiration.fragment.weather", defaultValue: "Today's weather is"),
        String(localized: "inspiration.fragment.sun", defaultValue: "The sun rises from the east"),
        String(localized: "inspiration.fragment.math", defaultValue: "2 + 2 ="),
        String(localized: "inspiration.fragment.capital", defaultValue: "The capital of China is"),
    ]

    let fragments: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(fragments, id: \.self) { f in
                    Button {
                        onTap(f)
                    } label: {
                        Text(f)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    InspirationButtonsView(
        fragments: InspirationButtonsView.defaultFragments,
        onTap: { _ in }
    )
    .padding()
}
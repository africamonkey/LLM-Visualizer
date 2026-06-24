//
//  InspirationButtonsView.swift
//

import SwiftUI

struct InspirationButtonsView: View {

    static let defaultFragments: [String] = [
        "我爱吃",
        "明天我要去",
        "人生最重要的是",
        "今天天气真",
        "太阳从东边",
        "2 + 2 =",
        "中国的首都是",
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
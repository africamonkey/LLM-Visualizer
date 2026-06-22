//
//  JumpToBottomButton.swift
//

import SwiftUI

struct JumpToBottomButton: View {
    let action: () -> Void
    @State private var tapCounter: Int = 0

    var body: some View {
        Button {
            tapCounter += 1
            action()
        } label: {
            Image(systemName: "arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: .circle)
                .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce, value: tapCounter)
    }
}
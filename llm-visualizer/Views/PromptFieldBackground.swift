//
//  PromptFieldBackground.swift
//

import SwiftUI

struct PromptFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
}
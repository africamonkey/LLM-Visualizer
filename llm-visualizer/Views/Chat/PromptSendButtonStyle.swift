//
//  PromptSendButtonStyle.swift
//

import SwiftUI

struct PromptSendButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                color.opacity(configuration.isPressed ? 0.7 : 1.0),
                in: .rect(cornerRadius: 12)
            )
            .opacity(isEnabled ? 1.0 : 0.35)
    }

    @Environment(\.isEnabled) private var isEnabled
}
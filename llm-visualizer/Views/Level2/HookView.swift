//
//  HookView.swift
//

import SwiftUI

struct HookView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            VStack(spacing: 16) {
                Text(String(
                    localized: "level2.hook.body",
                    defaultValue: "AI actually doesn't know any characters at all. The world it sees looks very strange."
                ))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            Spacer()
            Button(action: onContinue) {
                Text(String(
                    localized: "level2.hook.cta",
                    defaultValue: "Show me"
                ))
                .font(.body.weight(.semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
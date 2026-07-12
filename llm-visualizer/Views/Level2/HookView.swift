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
                Text("🧩")
                    .font(.system(size: 56))
                Text(String(
                    localized: "level2.hook.body",
                    defaultValue: "Here's a secret: AI doesn't actually read characters. When you feed it text, it chops what you wrote into blocks first — like pieces of a puzzle. Want to see what its world looks like?"
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
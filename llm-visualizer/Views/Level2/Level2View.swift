//
//  Level2View.swift
//

import SwiftUI

struct Level2View: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String(
                localized: "level2.title",
                defaultValue: "Level 2 is on the way"
            ))
            .font(.title2.weight(.bold))
            .multilineTextAlignment(.center)
            Text(String(
                localized: "level2.body",
                defaultValue: "We're keeping building. Stay tuned."
            ))
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    Level2View()
}

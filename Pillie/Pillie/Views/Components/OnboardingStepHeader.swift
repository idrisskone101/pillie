//
//  OnboardingStepHeader.swift
//  Pillie
//

import SwiftUI

struct OnboardingStepHeader: View {
    let appeared: Bool
    let progress: CGFloat
    let trailingLabel: String?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(PillieTheme.sage, in: Circle())
            }

            GeometryReader { geo in
                Capsule()
                    .fill(PillieTheme.sage)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(PillieTheme.coral)
                            .frame(width: appeared ? geo.size.width * min(max(progress, 0), 1) : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                    }
            }
            .frame(height: 6)

            if let trailingLabel {
                Text(trailingLabel)
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 40, height: 40)
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
    }
}

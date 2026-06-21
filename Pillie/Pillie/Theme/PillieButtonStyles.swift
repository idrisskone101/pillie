//
//  PillieButtonStyles.swift
//  Pillie
//

import SwiftUI

struct PillieDarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(18, weight: .semibold))
            // The fixed-height capsule can't grow, so at large Dynamic Type sizes
            // keep the CTA on one line and scale it down to fit instead of letting
            // the label truncate ("Try Pillie Plus for fr…"). No-op at default size.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(PillieTheme.dark)
            .clipShape(Capsule())
            .shadow(color: PillieTheme.dark.opacity(0.5), radius: 15, y: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PillieSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(16, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(PillieTheme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .fill(configuration.isPressed ? PillieTheme.lavender.opacity(0.5) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillieDarkButtonStyle {
    static var pillieDark: PillieDarkButtonStyle { PillieDarkButtonStyle() }
}

extension ButtonStyle where Self == PillieSecondaryButtonStyle {
    static var pillieSecondary: PillieSecondaryButtonStyle { PillieSecondaryButtonStyle() }
}

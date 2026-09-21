import SwiftUI

struct PillieTakenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(18, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .pillieAdaptiveLineLimit(minimumScaleFactor: 0.65)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(PillieTheme.sage)
            .clipShape(Capsule())
    }
}

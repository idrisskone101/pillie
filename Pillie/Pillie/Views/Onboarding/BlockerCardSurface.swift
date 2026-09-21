import SwiftUI

// MARK: - Card surface

struct BlockerCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .fill(PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: PillieTheme.cardShadow,
                radius: PillieTheme.cardShadowRadius,
                y: PillieTheme.cardShadowY
            )
    }
}

//
//  RefillBannerCard.swift
//  Pillie
//

import SwiftUI

struct RefillBannerCard: View {
    @Environment(PillStore.self) var store
    @Environment(\.locale) private var locale
    let onRefill: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Circle()
                .fill(PillieTheme.coral)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                )

            // Title
            Text(PillieLocalization.string("today.refill.title", locale: locale))
                .font(.pillie(20, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)

            // Subtitle
            Text(PillieLocalization.formatted(
                "today.pack.start_new.body",
                locale: locale,
                arguments: CycleNounPresentation.localizedNoun(
                    for: store.pack.method,
                    locale: locale
                )
            ))
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)

            // CTA
            Button(action: onRefill) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                    Text(PillieLocalization.string(
                        "today.pack.start_new.confirm",
                        locale: locale
                    ))
                }
            }
            .buttonStyle(.pillieDark)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(PillieTheme.coralLight)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.coral.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }
}

#Preview {
    RefillBannerCard(onRefill: {})
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}

//
//  HistoryDiscoveryBanner.swift
//  Pillie
//

import SwiftUI

enum HistoryDiscoveryAnnouncement {
    static let storageKey = "historyDayCorrectionDiscoveryDismissed"
}

struct HistoryDiscoveryBanner: View {
    let onDismiss: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PillieTheme.patchChangeRose)
                .frame(width: 36, height: 36)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(PillieLocalization.string("history.discovery.new", locale: locale))
                    .font(.pillie(11, weight: .bold))
                    .tracking(0.88)
                    .foregroundStyle(PillieTheme.patchChangeRose)

                Text(PillieLocalization.string("history.discovery.banner", locale: locale))
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.dark)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                PillieLocalization.string("history.discovery.dismiss", locale: locale)
            )
            .accessibilityIdentifier("historyDayCorrectionBannerDismiss")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PillieTheme.coralLight)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("historyDayCorrectionBanner")
    }
}

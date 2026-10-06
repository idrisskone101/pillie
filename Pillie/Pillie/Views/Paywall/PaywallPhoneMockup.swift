//
//  PaywallPhoneMockup.swift
//  Pillie
//
//  Decorative iPhone showing the app-blocking shield, behind the paywall sheet.
//

import SwiftUI

struct PaywallPhoneMockup: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale

    /// Point size of the `PaywallPhone` frame art, side buttons included.
    private static let size = CGSize(width: 258, height: 548)
    /// Where the art's screen starts: side button gutter plus bezel.
    private static let screenOrigin = CGPoint(x: 10, y: 7)

    var body: some View {
        Image("PaywallPhone")
            .resizable()
            .frame(width: Self.size.width, height: Self.size.height)
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    statusRow
                        .padding(.top, 14)
                        .padding(.horizontal, 28)

                    shield
                        .padding(.top, 117)
                }
                .padding(.horizontal, Self.screenOrigin.x)
                .padding(.top, Self.screenOrigin.y)
            }
            .accessibilityHidden(true)
    }

    private var statusRow: some View {
        Text(reminderTime)
            .font(.pillie(13, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
    }

    private var shield: some View {
        VStack(spacing: 0) {
            Image("HomeAvatarLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())

            Text(commerce("paywall.mockup.shield.title"))
                .font(.pillie(16, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.top, 18)

            Text(commerce("paywall.mockup.shield.subtitle") + " " + commerce("paywall.mockup.shield.secondary"))
                .font(.pillie(12, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .padding(.top, 8)
                .padding(.horizontal, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }

    private var reminderTime: String {
        let date = Calendar.current.date(
            bySettingHour: store.reminderHour,
            minute: store.reminderMinute,
            second: 0,
            of: .now
        ) ?? .now
        return date.formatted(
            Date.FormatStyle()
                .locale(locale)
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
        )
    }

    private func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }
}

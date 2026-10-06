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

    private static let size = CGSize(width: 252, height: 548)
    private static let bodyRadius: CGFloat = 46
    private static let screenInset: CGFloat = 7
    private static let screenRadius: CGFloat = 39
    private static let rimLight = Color(hex: "3C3636")
    private static let rimDark = Color(hex: "1C1A1A")

    var body: some View {
        RoundedRectangle(cornerRadius: Self.bodyRadius, style: .continuous)
            .fill(Color(hex: "100E0F"))
            .overlay {
                RoundedRectangle(cornerRadius: Self.bodyRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Self.rimLight, Self.rimDark],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            }
            .overlay {
                screen
                    .padding(Self.screenInset)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .overlay(alignment: .topLeading) {
                sideButton(length: 22, top: 96, leading: true)
                sideButton(length: 40, top: 140, leading: true)
                sideButton(length: 40, top: 192, leading: true)
            }
            .overlay(alignment: .topTrailing) {
                sideButton(length: 62, top: 156, leading: false)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .accessibilityHidden(true)
    }

    private var screen: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Self.screenRadius, style: .continuous)
                .fill(Color(hex: "FCF2F0"))

            Capsule()
                .fill(Color.black)
                .frame(width: 74, height: 22)
                .padding(.top, 11)

            statusRow
                .padding(.top, 14)
                .padding(.horizontal, 28)

            shield
                .padding(.top, 117)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.screenRadius, style: .continuous))
    }

    private var statusRow: some View {
        HStack(spacing: 0) {
            Text(reminderTime)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 10))
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .frame(width: 18, height: 8)
            }
            .foregroundStyle(PillieTheme.textPrimary)
        }
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

    private func sideButton(length: CGFloat, top: CGFloat, leading: Bool) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Self.rimDark)
            .frame(width: 3, height: length)
            .offset(x: leading ? -3 : 3, y: top)
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

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let shield: PaywallPhoneShield

    /// Counts flips into `.plusOn`; a first appearance already on stays at zero.
    @State private var plusArrivals = 0
    @State private var successHaptics = 0

    /// Point size of the `PaywallPhone` frame art, side buttons included.
    private static let size = CGSize(width: 258, height: 548)
    /// Where the art's screen starts: side button gutter plus bezel.
    private static let screenOrigin = CGPoint(x: 10, y: 7)

    init(shield: PaywallPhoneShield = .paused) {
        self.shield = shield
    }

    var body: some View {
        Image("PaywallPhone")
            .resizable()
            .frame(width: Self.size.width, height: Self.size.height)
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    statusRow
                        .padding(.top, 14)
                        .padding(.horizontal, 28)

                    pausedShield
                        .padding(.top, 117)
                        .animation(reduceMotion ? PaywallSuccessMotion.fadeIn : PaywallSuccessMotion.shieldFade) {
                            $0.opacity(shield.isPlusOn ? 0 : 1)
                        }

                    PaywallPlusShield(line: shield.line, isOn: shield.isPlusOn)
                        .padding(.top, 81)
                }
                .padding(.horizontal, Self.screenOrigin.x)
                .padding(.top, Self.screenOrigin.y)
            }
            .accessibilityHidden(true)
            .onChange(of: shield.isPlusOn) { _, isPlusOn in
                if isPlusOn { plusArrivals += 1 }
            }
            .task(id: plusArrivals) {
                guard plusArrivals > 0 else { return }
                try? await Task.sleep(for: reduceMotion ? PaywallSuccessMotion.reducedHapticDelay : PaywallSuccessMotion.hapticDelay)
                guard !Task.isCancelled else { return }
                successHaptics += 1
            }
            .sensoryFeedback(.success, trigger: successHaptics)
    }

    private var statusRow: some View {
        Text(reminderTime)
            .font(.pillie(13, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
    }

    private var pausedShield: some View {
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

enum PaywallPhoneShield: Equatable {
    case paused
    case plusOn(line: String)

    var isPlusOn: Bool {
        if case .plusOn = self { true } else { false }
    }

    fileprivate var line: String {
        if case .plusOn(let line) = self { line } else { "" }
    }
}

/// The shield after a purchase: rings, the Pillie mark with a check badge, "Plus is on".
/// Laid out at rest whatever `isOn` says, so `isOn` only fades and scales.
private struct PaywallPlusShield: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let line: String
    let isOn: Bool

    private static let rose = PillieTheme.patchChangeRose

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                rings
                    .animation(reduceMotion ? PaywallSuccessMotion.fadeIn : PaywallSuccessMotion.rings) {
                        $0.scaleEffect(isOn || reduceMotion ? 1 : 0.92).opacity(isOn ? 1 : 0)
                    }

                Image("HomeAvatarLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .shadow(color: Color(hex: "783C32").opacity(0.22), radius: 9, y: 8)
                    .animation(fade) { $0.opacity(isOn ? 1 : 0) }

                badge
                    .animation(reduceMotion ? PaywallSuccessMotion.fadeIn : PaywallSuccessMotion.badge) {
                        $0.scaleEffect(isOn || reduceMotion ? 1 : 1.4).opacity(isOn ? 1 : 0)
                    }
                    // Bottom -4, right -6 off the 72 pt mark, from the ZStack's center.
                    .offset(x: 36 + 6 - 15, y: 36 + 4 - 15)
            }
            .frame(width: 150, height: 150)

            Group {
                Text(PillieLocalization.string("paywall.mockup.plus.title", table: "Commerce", locale: locale))
                    .font(.pillie(18, weight: .extraBold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .padding(.top, 12)

                Text(line)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(2)
                    .padding(.top, 6)
                    .padding(.horizontal, 22)
            }
            .multilineTextAlignment(.center)
            .animation(fade) { $0.opacity(isOn ? 1 : 0) }
        }
        .frame(maxWidth: .infinity)
    }

    private var fade: Animation {
        reduceMotion ? PaywallSuccessMotion.fadeIn : PaywallSuccessMotion.shieldFade
    }

    private var rings: some View {
        ZStack {
            Circle()
                .strokeBorder(Self.rose.opacity(0.22), lineWidth: 1)
                .frame(width: 150, height: 150)
            Circle()
                .fill(Color.white.opacity(0.45))
                .strokeBorder(Self.rose.opacity(0.35), lineWidth: 1)
                .frame(width: 112, height: 112)
        }
    }

    private var badge: some View {
        Circle()
            .fill(PillieTheme.coral)
            .strokeBorder(PillieTheme.coralLight, lineWidth: 3)
            .frame(width: 30, height: 30)
            .overlay {
                PaywallCheckmark()
                    .stroke(PillieTheme.textPrimary, style: PaywallCheckmark.stroke(size: 14))
                    .frame(width: 14, height: 14)
            }
    }
}

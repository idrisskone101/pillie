//
//  CustomReminderLockScreen.swift
//  Pillie
//

import SwiftUI

/// A mock Lock Screen: wallpaper, lock glyph, today's date, the reminder time, and one
/// frosted banner per reminder. Banners show the effective copy that will fire.
struct CustomReminderLockScreenStage: View {
    let hour: Int
    let minute: Int
    let clockSize: CGFloat
    let daily: CustomReminderBannerContent
    let followup: CustomReminderBannerContent
    /// Every tone's copy per banner, so switching tones never changes a banner's height.
    var reserved: [CustomReminderKind: [CustomReminderBannerContent]] = [:]
    let onEdit: (CustomReminderKind) -> Void

    @Environment(\.locale) private var locale

    /// The reminder time the way the Lock Screen clock shows it: the locale's hour cycle
    /// without an AM/PM marker.
    private var clock: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        let template = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: locale) ?? "H:mm"
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = String(template.filter { !"abB".contains($0) })
            .trimmingCharacters(in: .whitespaces)
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CustomReminderLockScreenColor.clock)
                .accessibilityHidden(true)

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(locale)))
                .font(.pillie(15, weight: .semibold))
                .foregroundStyle(CustomReminderLockScreenColor.clock)

            Text(clock)
                .font(.pillie(clockSize, weight: .semibold))
                .tracking(clockSize * -0.04)
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.bottom, 10)

            CustomReminderNotificationBanner(
                content: daily,
                reserved: reserved[.daily] ?? [],
                timestamp: Date.now.formatted(.relative(presentation: .named).locale(locale)),
                kind: .daily,
                onEdit: onEdit
            )
            CustomReminderNotificationBanner(
                content: followup,
                reserved: reserved[.followup] ?? [],
                timestamp: PillieLocalization.string("settings.custom_messages.later", locale: locale),
                kind: .followup,
                onEdit: onEdit
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(CustomReminderWallpaper())
    }
}

struct CustomReminderBannerContent: Equatable {
    let title: String
    let body: String
}

struct CustomReminderWallpaper: View {
    private let shape = RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)

    var body: some View {
        shape
            .fill(LinearGradient(
                stops: [
                    .init(color: PillieTheme.lavender, location: 0),
                    .init(color: Color(hex: "F6EEF0"), location: 0.55),
                    .init(color: PillieTheme.coralLight, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay(shape.stroke(Color.white.opacity(0.7), lineWidth: 1))
    }
}

/// One frosted Lock Screen banner. VoiceOver reads the copy as one element and the pencil
/// as its own Edit button.
struct CustomReminderNotificationBanner: View {
    let content: CustomReminderBannerContent
    var reserved: [CustomReminderBannerContent] = []
    let timestamp: String
    let kind: CustomReminderKind
    let onEdit: ((CustomReminderKind) -> Void)?

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image("HomeAvatarLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        ReservedText(text: content.title, reserved: reserved.map(\.title))
                            .font(.pillie(15, weight: .semibold))
                            .foregroundStyle(PillieTheme.textPrimary)
                            .lineLimit(2)
                            .accessibilityIdentifier("reminder-preview-\(kind.rawValue)-title")
                        Spacer(minLength: 0)
                        Text(timestamp)
                            .font(.pillie(12, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    ReservedText(text: content.body, reserved: reserved.map(\.body))
                        .font(.pillie(15))
                        .foregroundStyle(CustomReminderLockScreenColor.body)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reminder-preview-\(kind.rawValue)-body")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(content.title), \(content.body)")
            .accessibilityIdentifier("reminder-preview-\(kind.rawValue)")

            if let onEdit {
                Button { onEdit(kind) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(PillieTheme.sage))
                        .contentShape(Circle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PillieLocalization.string("global.action.edit", locale: locale))
                .accessibilityHint(content.title)
                .accessibilityIdentifier("reminder-edit-\(kind.rawValue)")
            }
        }
        .padding(.vertical, 13)
        .padding(.leading, 13)
        .padding(.trailing, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: PillieTheme.textPrimary.opacity(0.08), radius: 9, y: 6)
        )
    }
}

/// Text sized to the tallest of `reserved` in the same style, so swapping between them
/// never moves what sits below.
struct ReservedText: View {
    let text: String
    let reserved: [String]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(reserved.indices, id: \.self) { index in
                Text(reserved[index]).hidden()
            }
            Text(text)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private enum CustomReminderLockScreenColor {
    static let clock = Color(hex: "57534E")
    static let body = Color(hex: "44403C")
}

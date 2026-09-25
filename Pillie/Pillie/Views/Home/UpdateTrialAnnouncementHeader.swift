import SwiftUI

struct UpdateTrialAnnouncementHeader: View {
    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Text(badge)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(PillieTheme.coral, in: Capsule())

            (Text(title + " ")
                .foregroundStyle(PillieTheme.textPrimary)
                + Text(titleAccent)
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieExtraBold(26))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
    }
}

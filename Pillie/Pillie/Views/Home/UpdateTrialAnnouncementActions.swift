import SwiftUI

struct UpdateTrialAnnouncementActions: View {
    let disclosure: String
    let primaryCTA: String
    let dismissCTA: String
    let onSetUpBlocking: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(disclosure)
                .font(.pillie(12, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            Button(action: onSetUpBlocking) {
                Text(primaryCTA)
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)

            Button(action: onDismiss) {
                Text(dismissCTA)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }
        }
    }
}

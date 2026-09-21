import SwiftUI

struct TrialDeclineThankYouBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PillieTheme.verifiedGreen)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(PillieTheme.dark, in: Capsule())
        .shadow(color: PillieTheme.dark.opacity(0.22), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trialDeclineFeedbackThankYou")
    }
}

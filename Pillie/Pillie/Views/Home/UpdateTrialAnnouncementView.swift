//
//  UpdateTrialAnnouncementView.swift
//  Pillie
//
//  Issue #165 (Reverse Trial 6/10 / ADR 0007): the one-time announcement sheet
//  shown to an existing onboarded free user on first launch after the
//  introducing update — Plus is now free for them for 14 days. Copy is kept as
//  a value type so the pre-trial disclosure duty and the no-purchase-UI
//  boundary are testable without driving the SwiftUI view.
//

import SwiftUI

/// Copy for the update announcement sheet. Entirely fixed — nothing is
/// personalized.
struct UpdateTrialAnnouncementContent {
    struct Perk {
        let title: String
        let symbolName: String
    }

    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String
    /// The same four Plus perks the Trial Granted Moment lists.
    let perks: [Perk]
    /// The App Review pre-trial disclosures as one plain line — identical to the
    /// Trial Granted Moment's so the two grant surfaces can never drift.
    let disclosure: String
    /// The primary action — deep-links into the Settings blocker editor so setup
    /// completed there activates blocking under the trial.
    let primaryCTA: String
    /// The dismiss action. Unlike the onboarding Trial Granted Moment, the sheet
    /// interrupts an existing user's session, so it must offer a way out.
    let dismissCTA: String

    var visibleCopy: [String] {
        [badge, title, titleAccent, subtitle]
            + perks.map(\.title)
            + [disclosure, primaryCTA, dismissCTA]
    }

    static let `default` = UpdateTrialAnnouncementContent(
        badge: "14 days free · no card",
        title: "Pillie Plus is now",
        titleAccent: "free for you.",
        subtitle: "This update starts your full 14-day Plus trial — everything unlocks now.",
        perks: [
            Perk(title: "App blocking", symbolName: "nosign"),
            Perk(title: "Shake to confirm", symbolName: "iphone.radiowaves.left.and.right"),
            Perk(title: "Smart Reminders", symbolName: "bell.fill"),
            Perk(title: "Custom messages", symbolName: "text.bubble.fill"),
        ],
        disclosure: TrialGrantedMomentContent.default.disclosure,
        primaryCTA: "Set up app blocking",
        dismissCTA: "Not now"
    )
}

/// The one-time announcement sheet. Presentation-only: the grant itself and
/// `trial_granted` (source: update) are written by the flow container before
/// this sheet is presented, mirroring how the Trial Granted Moment stays
/// presentation-only.
struct UpdateTrialAnnouncementView: View {
    static let presentationHeight: CGFloat = 540

    private let content = UpdateTrialAnnouncementContent.default

    let onSetUpBlocking: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            UpdateTrialAnnouncementHeader(
                badge: content.badge,
                title: content.title,
                titleAccent: content.titleAccent,
                subtitle: content.subtitle
            )

            UpdateTrialPerkGrid(perks: content.perks)
                .padding(.horizontal, 28)

            Spacer(minLength: 0)

            UpdateTrialAnnouncementActions(
                disclosure: content.disclosure,
                primaryCTA: content.primaryCTA,
                dismissCTA: content.dismissCTA,
                onSetUpBlocking: onSetUpBlocking,
                onDismiss: onDismiss
            )
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PillieTheme.bg)
    }
}

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

struct UpdateTrialPerkGrid: View {
    let perks: [UpdateTrialAnnouncementContent.Perk]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(perks, id: \.title) { perk in
                HStack(spacing: 10) {
                    Image(systemName: perk.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                    Text(perk.title)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 20)
                .background(PillieTheme.sage.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

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

#Preview {
    UpdateTrialAnnouncementView(onSetUpBlocking: {}, onDismiss: {})
}

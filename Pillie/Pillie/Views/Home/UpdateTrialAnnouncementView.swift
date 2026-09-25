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

/// The one-time announcement sheet. Presentation-only: the grant itself and
/// `trial_granted` (source: update) are written by the flow container before
/// this sheet is presented, mirroring how the Trial Granted Moment stays
/// presentation-only.
struct UpdateTrialAnnouncementView: View {
    static let presentationHeight: CGFloat = 620

    @Environment(\.locale) private var locale
    private var content: UpdateTrialAnnouncementContent {
        UpdateTrialAnnouncementContent.localized(locale: locale)
    }

    let onSetUpBlocking: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
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

                UpdateTrialAnnouncementActions(
                    disclosure: content.disclosure,
                    primaryCTA: content.primaryCTA,
                    dismissCTA: content.dismissCTA,
                    onSetUpBlocking: onSetUpBlocking,
                    onDismiss: onDismiss
                )
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PillieTheme.bg)
    }
}

#Preview {
    UpdateTrialAnnouncementView(onSetUpBlocking: {}, onDismiss: {})
}

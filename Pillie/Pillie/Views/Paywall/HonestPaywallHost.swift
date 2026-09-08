//
//  HonestPaywallHost.swift
//  Pillie
//

import SwiftUI

struct HonestPaywallHost: View {
    @Environment(\.locale) private var locale

    let entry: PaywallEntryPoint
    let surface: AnalyticsPaywallSurface
    var trialStats: TrialEndOwnStats? = nil
    var declineFeedbackContent: TrialDeclineFeedbackContent? = nil
    var routeContinueFree: (() -> TrialDeclineFeedbackRoute)? = nil
    let onDismiss: () -> Void
    var onResolved: (() -> Void)? = nil

    private let subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Group {
            if let board = resolvedBoard {
                HonestPaywallScreen(
                    board: board,
                    surface: surface,
                    onDismiss: onDismiss,
                    onResolved: onResolved,
                    trialStats: trialStats,
                    declineFeedbackContent: declineFeedbackContent,
                    routeContinueFree: routeContinueFree
                )
            } else {
                Color.clear
                    .onAppear(perform: onDismiss)
            }
        }
    }

    private var resolvedBoard: HonestPaywallBoard? {
        HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(
                hasEntitlement: subscriptionManager.hasEntitlement,
                trialGrantDate: subscriptionManager.trialGrantDate
            ),
            entry: entry,
            stats: trialStats,
            calendar: .current,
            now: Date(),
            locale: locale,
            hardPaywallEnabled: subscriptionManager.hardPaywallEnabled,
            termsCohort: subscriptionManager.trialTermsCohort
        )
    }
}

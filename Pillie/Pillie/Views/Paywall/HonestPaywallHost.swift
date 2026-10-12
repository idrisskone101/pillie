//
//  HonestPaywallHost.swift
//  Pillie
//

import SwiftUI

struct HonestPaywallHost: View {
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store

    let entry: PaywallEntryPoint
    let surface: AnalyticsPaywallSurface
    var trialStats: TrialEndOwnStats? = nil
    /// App Review only: show the board even to someone who already has Plus.
    var showsToSubscriber = false
    var declineFeedbackContent: TrialDeclineFeedbackContent? = nil
    var routeContinueFree: (() -> TrialDeclineFeedbackRoute)? = nil
    let onDismiss: () -> Void
    var onResolved: (() -> Void)? = nil

    /// The board this presentation opened on. A purchase turns Plus on, which
    /// resolves to no board, and the success screen must outlive that.
    @State private var openedBoard: HonestPaywallBoard?

    private let subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Group {
            if let board = openedBoard ?? resolvedBoard {
                HonestPaywallScreen(
                    board: board,
                    surface: surface,
                    onDismiss: onDismiss,
                    onResolved: onResolved,
                    trialStats: trialStats,
                    declineFeedbackContent: declineFeedbackContent,
                    routeContinueFree: routeContinueFree
                )
                .onAppear { openedBoard = board }
            } else {
                Color.clear
                    .onAppear(perform: onDismiss)
            }
        }
    }

    private var resolvedBoard: HonestPaywallBoard? {
        var access = subscriptionManager.plusAccessState
        if showsToSubscriber { access.hasEntitlement = false }
        return HonestPaywallBoardResolver.resolve(
            access: access,
            entry: entry,
            method: store.pack.method,
            calendar: .current,
            now: Date(),
            locale: locale,
            hardPaywallEnabled: subscriptionManager.hardPaywallEnabled,
            termsCohort: subscriptionManager.trialTermsCohort
        )
    }
}

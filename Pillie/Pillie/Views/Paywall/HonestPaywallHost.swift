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
    var declineFeedbackContent: TrialDeclineFeedbackContent? = nil
    var routeContinueFree: (() -> TrialDeclineFeedbackRoute)? = nil
    let onDismiss: () -> Void
    var onResolved: (() -> Void)? = nil

    /// The board and arm this presentation opened on. A purchase turns Plus on,
    /// which resolves to no board, and the success screen must outlive that.
    @State private var opened: OpenedPaywall?

    private let subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Group {
            if let presentation = opened ?? resolved {
                HonestPaywallScreen(
                    board: presentation.board,
                    surface: surface,
                    onDismiss: onDismiss,
                    onResolved: onResolved,
                    trialStats: trialStats,
                    declineFeedbackContent: declineFeedbackContent,
                    routeContinueFree: routeContinueFree
                )
                .onAppear {
                    guard opened == nil else { return }
                    opened = presentation
                    PaywallDesignEnrollment.expose(presentation.design)
                }
            } else {
                Color.clear
                    .onAppear(perform: onDismiss)
            }
        }
    }

    private var resolved: OpenedPaywall? {
        let design = PaywallDesignEnrollment.current()
        return HonestPaywallBoardResolver.resolve(
            access: subscriptionManager.plusAccessState,
            entry: entry,
            method: store.pack.method,
            design: design.design,
            trialStats: trialStats,
            calendar: .current,
            now: Date(),
            locale: locale,
            hardPaywallEnabled: subscriptionManager.hardPaywallEnabled,
            termsCohort: subscriptionManager.trialTermsCohort
        ).map { OpenedPaywall(board: $0, design: design) }
    }
}

private struct OpenedPaywall: Equatable {
    let board: HonestPaywallBoard
    let design: PaywallDesignAssignment
}

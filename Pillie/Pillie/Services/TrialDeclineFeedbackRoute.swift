//
//  TrialDeclineFeedbackRoute.swift
//  Pillie
//
//  Pure high-level routing for issue #243. SwiftUI owns presentation while
//  this value decides whether an explicit Trial-End Paywall exit may ask for
//  optional decline feedback.
//

import Foundation

enum TrialEndPaywallExitAction: Equatable {
    case close
    case continueFree
}

enum TrialDeclineFeedbackRoute: Equatable {
    case enterFreeApp
    case presentFeedback

    static func evaluate(
        action: TrialEndPaywallExitAction,
        state: PlusAccessState,
        entitlementResolved: Bool,
        questionnaireResolved: Bool,
        calendar: Calendar,
        now: Date
    ) -> TrialDeclineFeedbackRoute {
        guard action == .continueFree,
              entitlementResolved,
              !questionnaireResolved,
              !state.hasEntitlement,
              state.trialGrantDate != nil,
              !state.trialActive(calendar: calendar, now: now)
        else {
            return .enterFreeApp
        }
        return .presentFeedback
    }
}

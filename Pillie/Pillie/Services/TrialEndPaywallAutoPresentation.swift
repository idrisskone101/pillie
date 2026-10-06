//
//  TrialEndPaywallAutoPresentation.swift
//  Pillie
//
//  The Trial-End Paywall's auto-present decision (issue #169 / issue #257):
//  legacy cohorts retain the exactly-once surface; hard-wall cohorts repeat
//  until Plus is active; a remote rollback gets one legacy presentation even
//  after the wall was shown. Pure value logic keeps those contracts testable.
//

import Foundation

enum TrialEndPaywallAutoPresentation {
    /// UserDefaults key for the persisted one-shot flag, set after presenting.
    static let shownStorageKey = "trialEndPaywallShown"
    /// One-shot legacy surface shown when operators roll a post-cutover cohort
    /// back after its hard wall had already appeared.
    static let rollbackShownStorageKey = "trialEndPaywallRollbackShown"

    /// Foreground reconciliation flips Plus access from active to inactive when
    /// a Reverse Trial expired while the app was suspended. That transition is
    /// the signal for Home to re-run the presentation decision immediately.
    static func shouldReevaluate(
        previousPlusAccess: Bool,
        currentPlusAccess: Bool
    ) -> Bool {
        previousPlusAccess && !currentPlusAccess
    }

    /// Whether this app open should auto-present the Trial-End Paywall. Same
    /// deferral seam as `TrialExpiredEvent`: while RevenueCat has not resolved
    /// entitlement this launch, `hasEntitlement` is still a stale `false`, so
    /// deciding early would misread a mid-trial converter as expired.
    static func shouldPresent(
        state: PlusAccessState,
        terms: TrialEndAccessTerms = .legacy,
        termsCohort: TrialTermsCohort = .preCutover,
        entitlementResolved: Bool,
        configurationResolved: Bool = true,
        alreadyShown: Bool,
        rollbackAlreadyShown: Bool = false,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        let shouldShowForTerms = terms == .hardPaywall
            || !alreadyShown
            || (termsCohort == .postCutover && !rollbackAlreadyShown)
        guard entitlementResolved, configurationResolved,
              shouldShowForTerms,
              !state.hasEntitlement,
              state.trialGrantDate != nil else {
            return false
        }
        return !state.trialActive(calendar: calendar, now: now)
    }
}

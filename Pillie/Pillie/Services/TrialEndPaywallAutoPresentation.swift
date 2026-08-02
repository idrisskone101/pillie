//
//  TrialEndPaywallAutoPresentation.swift
//  Pillie
//
//  The Trial-End Paywall's exactly-once auto-present decision (issue #169 /
//  ADR 0007): the sheet appears on the first launch at-or-after Reverse Trial
//  expiry and never auto-repeats after dismissal — the Protection Off card is
//  its re-entry point. Pure value logic so the once-only contract is testable;
//  the caller persists the shown flag.
//

import Foundation

enum TrialEndPaywallAutoPresentation {
    /// UserDefaults key for the persisted one-shot flag, set after presenting.
    static let shownStorageKey = "trialEndPaywallShown"

    /// Whether this app open should auto-present the Trial-End Paywall. Same
    /// deferral seam as `TrialExpiredEvent`: while RevenueCat has not resolved
    /// entitlement this launch, `hasEntitlement` is still a stale `false`, so
    /// deciding early would misread a mid-trial converter as expired.
    static func shouldPresent(
        state: PlusAccessState,
        terms: TrialEndAccessTerms = .legacy,
        entitlementResolved: Bool,
        configurationResolved: Bool = true,
        alreadyShown: Bool,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        guard entitlementResolved, configurationResolved,
              terms == .hardPaywall || !alreadyShown,
              !state.hasEntitlement,
              state.trialGrantDate != nil else {
            return false
        }
        return !state.trialActive(calendar: calendar, now: now)
    }
}

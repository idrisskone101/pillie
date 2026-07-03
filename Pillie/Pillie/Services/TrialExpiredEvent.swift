//
//  TrialExpiredEvent.swift
//  Pillie
//
//  The `trial_expired` one-shot decision (issue #167 / ADR 0007): fired once,
//  on the first app open at-or-after Reverse Trial expiry. Pure value logic so
//  the exactly-once contract is testable; the caller persists the fired flag.
//

import Foundation

enum TrialExpiredEvent {
    /// UserDefaults key for the persisted one-shot flag, set after firing.
    static let firedStorageKey = "trialExpiredEventFired"

    /// Whether this app open should record `trial_expired`: a trial was granted,
    /// its window is over, the user did not convert (an entitled user's trial
    /// ending is invisible — Plus Access never flipped), and the flag is unset.
    /// While RevenueCat has not resolved entitlement this launch the decision
    /// defers (same seam as the #165 update grant): `hasEntitlement` starts
    /// false, so deciding early would misread a mid-trial converter as expired.
    static func shouldFire(
        state: PlusAccessState,
        entitlementResolved: Bool,
        alreadyFired: Bool,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        guard entitlementResolved, !alreadyFired, !state.hasEntitlement,
              state.trialGrantDate != nil else {
            return false
        }
        return !state.trialActive(calendar: calendar, now: now)
    }
}

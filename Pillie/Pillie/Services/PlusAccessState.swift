//
//  PlusAccessState.swift
//  Pillie
//

import Foundation

/// Plus Access (CONTEXT.md): the single gate every Pillie Plus feature checks.
/// A user has Plus Access iff they hold a Plus entitlement or an active
/// Reverse Trial — there is no per-feature trial gating. This value type is the
/// one place that predicate lives; `SubscriptionManager` evaluates it and every
/// feature reads the manager's `hasPlusAccess`.
struct PlusAccessState: Equatable {
    /// Whether RevenueCat reports the `pillie_plus` entitlement as active.
    var hasEntitlement: Bool
    /// The persisted Reverse Trial grant moment, if one was ever granted.
    var trialGrantDate: Date?

    /// Derived, never stored (ADR 0007): whether the Reverse Trial covers `now`.
    func trialActive(calendar: Calendar, now: Date) -> Bool {
        guard let trialGrantDate else { return false }
        return ReverseTrialClock(grantDate: trialGrantDate)
            .isActive(calendar: calendar, now: now)
    }

    /// The Plus Access predicate: entitlement || active trial.
    func hasPlusAccess(calendar: Calendar, now: Date) -> Bool {
        hasEntitlement || trialActive(calendar: calendar, now: now)
    }
}

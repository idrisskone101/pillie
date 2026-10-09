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
    /// Pack rhythm the clock walks. Calendar-day fixtures pass
    /// `.everyCalendarDay`. Production state carries the last pack snapshot.
    var schedule: ActiveDaySchedule = .everyCalendarDay
    /// Days the trial counted under earlier pack rhythms; `schedule` counts the rest.
    var trialLivedDays: TrialLivedDays? = nil

    /// The Reverse Trial clock every trial surface reads, if a trial was ever granted.
    var trialClock: ReverseTrialClock? {
        trialGrantDate.map {
            ReverseTrialClock(grantDate: $0, schedule: schedule, lived: trialLivedDays)
        }
    }

    /// Derived, never stored (ADR 0007): whether the Reverse Trial covers `now`.
    func trialActive(calendar: Calendar, now: Date) -> Bool {
        trialClock?.isActive(calendar: calendar, now: now) ?? false
    }

    /// The Plus Access predicate: entitlement || active trial.
    func hasPlusAccess(calendar: Calendar, now: Date) -> Bool {
        hasEntitlement || trialActive(calendar: calendar, now: now)
    }
}

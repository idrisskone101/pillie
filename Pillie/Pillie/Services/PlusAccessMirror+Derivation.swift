//
//  PlusAccessMirror+Derivation.swift
//  Pillie
//
//  App-target-only half of the Plus Access mirror (issue #167): deriving the
//  valid-until date needs PlusAccessState and ReverseTrialClock, which the
//  sandboxed extension does not compile. The extension only ever evaluates
//  `allowsBlocking` against the stored value.
//

import Foundation

extension PlusAccessMirror {
    /// The moment Plus Access is known to end, derived from the authoritative
    /// access state. A trial-only user is valid exactly until the Reverse Trial
    /// clock's expiry moment (local midnight after day 14). An entitled user
    /// never expires from the shield's point of view — churn is handled by the
    /// next in-app refresh, never by the extension guessing at renewal dates.
    static func validUntil(state: PlusAccessState, calendar: Calendar) -> Date {
        if state.hasEntitlement { return .distantFuture }
        guard let grantDate = state.trialGrantDate else { return .distantPast }
        return ReverseTrialClock(grantDate: grantDate).expiryMoment(calendar: calendar)
    }
}

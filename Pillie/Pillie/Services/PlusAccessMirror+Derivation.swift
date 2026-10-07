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
    /// clock's expiry moment (local midnight after the 14th full hormone-active
    /// day). An entitled user never expires from the shield's point of view —
    /// churn is handled by the next in-app refresh, never by the extension
    /// guessing at renewal dates.
    static func validUntil(state: PlusAccessState, calendar: Calendar) -> Date {
        if state.hasEntitlement { return .distantFuture }
        guard let clock = state.trialClock else { return .distantPast }
        return clock.expiryMoment(calendar: calendar)
    }

    /// The one-off DeviceActivity interval that wakes the monitor when Plus
    /// Access ends, so its access check drops shields then even with Pillie
    /// closed. Nil when access has no end ahead.
    static func expiryWakeInterval(
        validUntil: Date,
        now: Date,
        calendar: Calendar
    ) -> (start: DateComponents, end: DateComponents)? {
        guard validUntil > now, validUntil < .distantFuture,
              let end = calendar.date(byAdding: .minute, value: expiryWakeMinutes, to: validUntil)
        else { return nil }
        return (wakeComponents(validUntil, calendar: calendar), wakeComponents(end, calendar: calendar))
    }

    /// DeviceActivity refuses intervals shorter than 15 minutes.
    private static let expiryWakeMinutes = 15

    /// Full date components, so the schedule fires once instead of daily.
    private static func wakeComponents(_ date: Date, calendar: Calendar) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
    }
}

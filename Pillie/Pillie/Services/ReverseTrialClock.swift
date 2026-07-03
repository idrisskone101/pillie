//
//  ReverseTrialClock.swift
//  Pillie
//

import Foundation

/// The pure Reverse Trial clock (PRD #159 / ADR 0007): derives whether a trial
/// is active from `(grant timestamp, calendar, now)`. Nothing here is stored —
/// `trialActive` must always be recomputed from the grant date so the clock
/// cannot drift from persisted state.
///
/// The trial covers 14 *full* local calendar days from the grant: the grant day
/// itself is a partial bonus day (day 0), days 1–14 are the full days, and the
/// trial expires at the local-day rollover after day 14. A 23:59 grant therefore
/// still receives 14 full days, and expiry never lands mid-blocking-window.
struct ReverseTrialClock: Equatable {
    /// The number of full local calendar days a Reverse Trial covers.
    static let fullDays = 14

    let grantDate: Date

    /// The moment Plus Access from this trial ends: local midnight after the
    /// 14th full calendar day following the grant day.
    func expiryMoment(calendar: Calendar) -> Date {
        let grantDayStart = calendar.startOfDay(for: grantDate)
        return calendar.date(byAdding: .day, value: Self.fullDays + 1, to: grantDayStart) ?? grantDayStart
    }

    func isActive(calendar: Calendar, now: Date) -> Bool {
        now < expiryMoment(calendar: calendar)
    }

    /// The number of local-day rollovers left before expiry, clamped at 0.
    /// `1` means the trial expires tonight; on the partial grant day this is
    /// `fullDays + 1` because tonight's rollover precedes the 14 full days.
    func daysRemaining(calendar: Calendar, now: Date) -> Int {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: expiryMoment(calendar: calendar)
        ).day ?? 0
        return max(0, days)
    }
}

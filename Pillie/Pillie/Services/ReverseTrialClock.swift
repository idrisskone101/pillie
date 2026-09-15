//
//  ReverseTrialClock.swift
//  Pillie
//

import Foundation

/// The pure Reverse Trial clock (PRD #159 / ADR 0007). Derives whether a trial
/// is active from `(grant timestamp, active-day schedule, calendar, now)`.
/// Nothing here is stored. `trialActive` must always be recomputed from the
/// grant date so the clock cannot drift from persisted state.
///
/// The grant local day is a bonus counted day, active or break. After that,
/// only active-phase days consume the 14 full days. Expiry is local midnight
/// after the 14th full counted active-phase day.
struct ReverseTrialClock: Equatable {
    /// The number of full active-phase days a Reverse Trial covers after grant day.
    static let fullDays = 14

    /// Bound on the local-day walk. A zero-active-days schedule never reaches
    /// `fullDays`, so without a cap this search would not halt.
    private static let maxWalkDays = 400

    let grantDate: Date
    let schedule: ActiveDaySchedule

    init(grantDate: Date, schedule: ActiveDaySchedule = .everyCalendarDay) {
        self.grantDate = grantDate
        self.schedule = schedule
    }

    /// Local midnight after the 14th full active-phase day following grant day.
    /// If those 14 days cannot be found within `maxWalkDays` (all-break pack),
    /// expiry is the local start of the cap day so Plus Access cannot stay on
    /// forever.
    func expiryMoment(calendar: Calendar) -> Date {
        let grantDay = calendar.startOfDay(for: grantDate)
        var cursor = grantDay
        var fullActiveDays = 0

        for _ in 0..<Self.maxWalkDays {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                return cursor
            }
            cursor = next
            if schedule.isActiveDay(cursor, calendar: calendar) {
                fullActiveDays += 1
                if fullActiveDays == Self.fullDays {
                    return calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
                }
            }
        }

        return cursor
    }

    func isActive(calendar: Calendar, now: Date) -> Bool {
        now < expiryMoment(calendar: calendar)
    }

    /// Count of remaining counted days (grant local day or active-phase) in
    /// `[startOfDay(now), expiryMoment)`. Break days are skipped so the badge
    /// freezes across a break.
    func daysRemaining(calendar: Calendar, now: Date) -> Int {
        let expiry = expiryMoment(calendar: calendar)
        let nowDay = calendar.startOfDay(for: now)
        if nowDay >= expiry { return 0 }

        var cursor = nowDay
        var remaining = 0
        var walked = 0
        while cursor < expiry && walked < Self.maxWalkDays {
            if isCountedDay(cursor, calendar: calendar) {
                remaining += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
            walked += 1
        }
        return remaining
    }

    /// User-facing day count. The trial promises "14 days free", so the
    /// partial grant day (15 counted days left) never reads above the promise.
    static func displayedDaysRemaining(_ daysRemaining: Int) -> Int {
        min(max(0, daysRemaining), fullDays)
    }

    func displayedDaysRemaining(calendar: Calendar, now: Date) -> Int {
        Self.displayedDaysRemaining(daysRemaining(calendar: calendar, now: now))
    }

    /// True when expiry is the next local midnight. A break day with one
    /// counted day still ahead is not tonight.
    func endsTonight(calendar: Calendar, now: Date) -> Bool {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return false
        }
        return expiryMoment(calendar: calendar) == tomorrow
    }

    private func isCountedDay(_ date: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, inSameDayAs: grantDate)
            || schedule.isActiveDay(date, calendar: calendar)
    }
}

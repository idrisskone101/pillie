//
//  ReverseTrialClock.swift
//  Pillie
//

import Foundation

/// The pure Reverse Trial clock (PRD #159 / ADR 0007). Derives whether a trial
/// is active from `(grant timestamp, active-day schedule, days already lived,
/// calendar, now)`. `trialActive` must always be recomputed from the grant
/// date so the clock cannot drift from persisted state.
///
/// The grant local day is a bonus counted day, active or break. After that,
/// only hormone-active days consume the 14 full days. Expiry is local midnight
/// after the 14th full counted hormone-active day. Break weeks freeze the
/// badge and leave Plus Access on.
struct ReverseTrialClock: Equatable {
    /// The number of full hormone-active days a Reverse Trial covers after grant day.
    static let fullDays = 14

    /// Worst legal custom is 1 active / 7 break. Fourteen full actives then
    /// fit in `fullDays * 8` local days. Bound the walk so a bad snapshot
    /// cannot hang.
    static let maximumWalkDays = fullDays * 8 + 2

    let grantDate: Date
    /// Counts the days from `lived.since` on, or from the grant when nil.
    let schedule: ActiveDaySchedule
    /// Days counted under earlier pack rhythms.
    let lived: TrialLivedDays?

    init(
        grantDate: Date,
        schedule: ActiveDaySchedule = .everyCalendarDay,
        lived: TrialLivedDays? = nil
    ) {
        self.grantDate = grantDate
        self.schedule = schedule
        self.lived = lived
    }

    /// Local midnight after the 14th full hormone-active day following grant day.
    /// Grant local day is never one of the 14, active or break. If those 14
    /// days cannot be found within `maximumWalkDays`, fall back to today's
    /// calendar-day expiry so Plus Access cannot stay on forever.
    func expiryMoment(calendar: Calendar) -> Date {
        let grantDay = calendar.startOfDay(for: grantDate)
        guard let firstFullDay = calendar.date(byAdding: .day, value: 1, to: grantDay) else {
            return grantDay
        }
        let start = lived.map { max(firstFullDay, calendar.startOfDay(for: $0.since)) } ?? firstFullDay
        let livedActiveDays = max(0, lived?.activeDays ?? 0)
        if livedActiveDays >= Self.fullDays { return start }
        var cursor = start
        var fullActiveDays = livedActiveDays

        for _ in 0..<Self.maximumWalkDays {
            if schedule.isActiveDay(cursor, calendar: calendar) {
                fullActiveDays += 1
                if fullActiveDays == Self.fullDays {
                    return calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return calendar.date(byAdding: .day, value: Self.fullDays - livedActiveDays, to: start) ?? grantDay
    }

    func isActive(calendar: Calendar, now: Date) -> Bool {
        now < expiryMoment(calendar: calendar)
    }

    /// Count of remaining counted days (grant local day or hormone-active) in
    /// `[startOfDay(now), expiryMoment)`. Break days are skipped so the badge
    /// freezes across a break.
    func daysRemaining(calendar: Calendar, now: Date) -> Int {
        let expiry = expiryMoment(calendar: calendar)
        let nowDay = calendar.startOfDay(for: now)
        if nowDay >= expiry { return 0 }

        var cursor = nowDay
        var remaining = 0
        var walked = 0
        while cursor < expiry && walked < Self.maximumWalkDays + Self.fullDays {
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

    /// User-facing day count. The trial promises "14 active days free", so the
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
        guard isActive(calendar: calendar, now: now) else { return false }
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return false
        }
        return expiryMoment(calendar: calendar) == tomorrow
    }

    /// Grant noon on the local day such that `now`'s local day is the 14th
    /// full hormone-active day. Nil if `now` is a break day.
    static func grantDatePlacingLastCountedDay(
        now: Date,
        calendar: Calendar,
        schedule: ActiveDaySchedule
    ) -> Date? {
        let lastFull = calendar.startOfDay(for: now)
        guard schedule.isActiveDay(lastFull, calendar: calendar) else { return nil }
        var found = 1
        var cursor = lastFull
        while found < fullDays {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return nil
            }
            cursor = previous
            if schedule.isActiveDay(cursor, calendar: calendar) {
                found += 1
            }
        }
        guard let grantDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
            return nil
        }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: grantDay) ?? grantDay
    }

    private func isCountedDay(_ date: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, inSameDayAs: grantDate)
            || schedule.isActiveDay(date, calendar: calendar)
    }
}

/// Hormone-active days a Reverse Trial counted under an earlier pack rhythm.
nonisolated struct TrialLivedDays: Codable, Equatable {
    /// Local midnight the current rhythm took over, or the expiry moment when
    /// all 14 days were lived before it.
    var since: Date
    /// Full hormone-active days after the grant day and before `since`.
    var activeDays: Int
}

/// The pack rhythm a Reverse Trial counts with, and the days it counted under
/// earlier rhythms. Saved beside the grant: a pack, regimen, or method change,
/// a relaunch, or a reinstall never reclassifies a day already lived.
/// `nonisolated` so the nonisolated Keychain grant store can encode it.
nonisolated struct TrialDayLedger: Codable, Equatable {
    var schedule: ActiveDaySchedule
    var lived: TrialLivedDays?
    /// The zone the ledger's local midnights were written in.
    var timeZoneIdentifier: String?

    /// The ledger once the pack rhythm becomes `newSchedule` at `now`. Days
    /// before today keep the rhythm they were lived with; today on follows
    /// the new one.
    @MainActor
    func adopting(
        _ newSchedule: ActiveDaySchedule,
        grantDate: Date,
        calendar: Calendar,
        now: Date
    ) -> TrialDayLedger {
        let ledger = moved(to: calendar)
        guard newSchedule != ledger.schedule,
              let firstFullDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: grantDate)
              )
        else { return ledger }

        let today = calendar.startOfDay(for: now)
        var day = ledger.lived.map { max(firstFullDay, calendar.startOfDay(for: $0.since)) } ?? firstFullDay
        var activeDays = max(0, ledger.lived?.activeDays ?? 0)
        while day < today, activeDays < ReverseTrialClock.fullDays {
            if ledger.schedule.isActiveDay(day, calendar: calendar) {
                activeDays += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return TrialDayLedger(
            schedule: newSchedule,
            lived: TrialLivedDays(since: day, activeDays: activeDays),
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }

    /// The same ledger with each local midnight moved onto its date in
    /// `calendar`'s zone, as `PillStore` moves stored days.
    @MainActor
    func moved(to calendar: Calendar) -> TrialDayLedger {
        var moved = self
        moved.timeZoneIdentifier = calendar.timeZone.identifier
        guard let timeZoneIdentifier, timeZoneIdentifier != calendar.timeZone.identifier else {
            return moved
        }
        let move = { StoredDay.day(of: $0, writtenIn: timeZoneIdentifier, calendar: calendar) }
        moved.schedule.anchorDate = move(schedule.anchorDate)
        if let since = lived?.since {
            moved.lived?.since = move(since)
        }
        return moved
    }
}

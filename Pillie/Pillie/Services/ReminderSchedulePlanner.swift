//
//  ReminderSchedulePlanner.swift
//  Pillie
//

import Foundation

struct ReminderSchedulePlanner {
    static let maxPendingReminders = 64
    static let baseReminderCount = 7
    static let dueScanLimit = 120
    static let catchupDelayMinutes = 1
    /// The streak is named only in its first week: the first reminders after
    /// onboarding (ENG-168).
    static let streakReminderRange = 1...6
    /// One row per Reverse Trial notice (#168 / ADR 0007). `day` names the
    /// request id, copy, and analytics value. Fire times are counted back from
    /// `ReverseTrialClock.expiryMoment`, not forward from the grant, so a break
    /// week that slides expiry moves the notices with it. Day 15 is the
    /// expiry-day notice: expiry is local midnight starting the first day
    /// without access, so 10:00 that day is the morning the wall appears. The
    /// hours are decoupled from the user's Due Action Reminder time so an
    /// informational notice never stacks on an action reminder.
    struct TrialNoticeSlot {
        let day: Int
        let calendarDaysBeforeExpiry: Int
        let hour: Int
    }

    static let trialNoticeSlots = [
        TrialNoticeSlot(day: 10, calendarDaysBeforeExpiry: 5, hour: 20),
        TrialNoticeSlot(day: 13, calendarDaysBeforeExpiry: 2, hour: 20),
        TrialNoticeSlot(day: 15, calendarDaysBeforeExpiry: 0, hour: 10),
    ]

    enum DueReminderKind: String {
        case base
        case retry
        case snooze
    }

    struct SnoozeOverride {
        let dueDayEpoch: Int
        let firstFireDate: Date
    }

    struct Input {
        let now: Date
        /// Live dose day (24-hour reminder window). Supply and cycle-transition
        /// planning, and due-action catch-up, use this — not civil midnight.
        let scheduleDay: Date
        let pack: PillPack
        let reminderHour: Int
        let reminderMinute: Int
        let autoReminderIntervalMinutes: Int
        let autoReminderRetryLimit: Int
        let refillReminderThresholdDays: Int
        let patchRestockReminderThresholdPatches: Int
        let candidateDueActions: [DoseScheduleAction]
        let statusByEpochDay: [Int: PillDay.Status]
        let snoozeOverride: SnoozeOverride?
        /// Whether Smart Reminders (Auto-Reminder Retry + Snooze re-fire) apply.
        /// Mirrors the `pillie_plus` entitlement. When false, the effective retry
        /// limit is forced to 0 and any snooze override is ignored, so a free user
        /// gets exactly one Due Action Reminder. The stored Interval/Retry Limit
        /// settings are never mutated — gating happens here, not in storage. See
        /// ADR 0004.
        let smartRemindersEnabled: Bool
        /// Whether the free Cycle Transition Notice is planned (#123). Defaults ON in
        /// Settings. This is NOT a Smart Reminders / Pillie+ perk — it is a free,
        /// informational notice and is deliberately independent of
        /// `smartRemindersEnabled`.
        let cycleTransitionEnabled: Bool
        /// The Reverse Trial grant moment, if any (ADR 0007). Drives the day-10/13
        /// expiry warnings and the day-15 expiry-day notice (#168); `nil` when no
        /// trial was ever granted.
        let trialGrantDate: Date?
        /// The raw Plus entitlement — NOT `hasPlusAccess`, which is true during the
        /// trial itself. Entitled users get no trial notices: a mid-trial purchase
        /// replans and the pending notices fall out as stale.
        let hasEntitlement: Bool
        /// Picks the trial notice copy: blocking-specific lines only make sense
        /// once the user has chosen apps to block.
        var trialCohort: TrialEndPaywallCohort = .reminderOnly
        /// Whether reminders continue after the trial. Only legacy
        /// (grandfathered) terms keep daily reminders free; hard-paywall
        /// reminders stop at trial expiry and the notices never promise them.
        var trialEndTerms: TrialEndAccessTerms = .hardPaywall
        /// `PillStore.currentStreak`: the run of taken due days before the
        /// nearest untaken one, i.e. what that day's reminder protects (ENG-168).
        var currentStreak: Int = 0
        /// For each untaken due day, the fire date of a base reminder already
        /// committed by NotificationManager (persisted, pending, or delivered).
        /// Empty → planner may emit first-time catch-up. Non-empty + fire <= now
        /// → suppress further base for that day. Non-empty + fire > now → re-plan
        /// the same fire date (stable request id across rebuilds).
        let servedBaseFireDateByDueDayEpoch: [Int: Date]
        let calendar: Calendar
    }

    struct DueReminderIntent: Hashable {
        let action: DoseScheduleAction
        let fireDate: Date
        let dueDayEpoch: Int
        let kind: DueReminderKind
        /// Set only on the base reminder for the nearest untaken due day, when
        /// it is a hormone pill, while the streak is in `streakReminderRange`
        /// (ENG-168). Later days stay `nil` because their streak depends on
        /// check-ins that haven't happened yet.
        var streakAtRisk: Int? = nil
    }

    struct SupplyReminderIntent: Hashable {
        let fireDate: Date
        let dueDayEpoch: Int
        let supplyUnitsLeft: Int
        let method: ContraceptiveMethod
    }

    /// The free Cycle Transition Notice (#123): a single informational notice fired at
    /// the user's reminder time on the first break/off-week day, explaining the upcoming
    /// silence and naming the date the active phase resumes. It fills the daily slot a
    /// Due Action Reminder would occupy on active days; on the break day that slot is
    /// otherwise empty.
    struct CycleTransitionIntent: Hashable {
        /// Start-of-day epoch of the first break/off-week day (the transition day).
        let transitionDayEpoch: Int
        let fireDate: Date
        let method: ContraceptiveMethod
        /// Start-of-day of the day the active phase resumes (the next active-phase start).
        let resumeDate: Date
    }

    /// A Reverse Trial notice (#168): a plain informational local notification
    /// on trial day 10, day 13, or day 15 (the expiry-day notice). Not a Smart
    /// Reminder: never gated by Plus, never a re-fire.
    struct TrialExpiryWarningIntent: Hashable {
        /// Trial day the notice belongs to (10, 13, or 15), grant day = day 0.
        let day: Int
        let fireDate: Date
        let cohort: TrialEndPaywallCohort
        let terms: TrialEndAccessTerms
    }

    enum Intent: Hashable {
        case due(DueReminderIntent)
        case supply(SupplyReminderIntent)
        case cycleTransition(CycleTransitionIntent)
        case trialExpiryWarning(TrialExpiryWarningIntent)

        /// Fire date of a reminder that needs app access; `nil` for the trial
        /// notices, which belong to the paywall.
        var reminderFireDate: Date? {
            switch self {
            case .due(let due): due.fireDate
            case .supply(let supply): supply.fireDate
            case .cycleTransition(let notice): notice.fireDate
            case .trialExpiryWarning: nil
            }
        }
    }

    func planReminders(_ input: Input) -> [Intent] {
        let intents = planAccessibleReminders(input)
        guard let accessEnd = hardPaywallAccessEnd(input) else { return intents }
        return intents.filter { intent in
            guard let fireDate = intent.reminderFireDate else { return true }
            return fireDate < accessEnd
        }
    }

    private func planAccessibleReminders(_ input: Input) -> [Intent] {
        // Smart Reminders gating: free users keep exactly one Due Action Reminder
        // with no auto-retries and no snooze re-fire. Supply reminders are planned
        // separately below and are unaffected. The stored settings are read but not
        // mutated (ADR 0004).
        let effectiveRetryLimit = input.smartRemindersEnabled ? input.autoReminderRetryLimit : 0
        let effectiveSnoozeOverride = input.smartRemindersEnabled ? input.snoozeOverride : nil

        let supplyIntent = planSupplyReminder(input)
        // The Cycle Transition Notice is free and not gated by `smartRemindersEnabled`.
        let cycleTransitionIntent = planCycleTransitionNotice(input)
        // Trial expiry warnings (#168) are informational, never Plus-gated.
        let trialWarningIntents = planTrialExpiryWarnings(input)
        let reservedAuxiliarySlots = (supplyIntent == nil ? 0 : 1)
            + (cycleTransitionIntent == nil ? 0 : 1)
            + trialWarningIntents.count
        let dueReminderBudget = max(0, Self.maxPendingReminders - reservedAuxiliarySlots)
        guard dueReminderBudget > 0 else {
            var auxiliary: [Intent] = []
            if let supplyIntent { auxiliary.append(.supply(supplyIntent)) }
            if let cycleTransitionIntent { auxiliary.append(.cycleTransition(cycleTransitionIntent)) }
            auxiliary.append(contentsOf: trialWarningIntents.map(Intent.trialExpiryWarning))
            return Array(auxiliary.prefix(Self.maxPendingReminders))
        }

        let dueActions = input.candidateDueActions.filter { action in
            // Break and passive days are never reminder-bearing, even if a
            // stale or malformed candidate bypasses DoseScheduleEngine's scan.
            guard action.type.requiresUserAction else { return false }
            let key = epochDay(for: action.date, calendar: input.calendar)
            return input.statusByEpochDay[key] != .taken
        }
        let baseDueActions = Array(dueActions.prefix(min(Self.baseReminderCount, dueReminderBudget)))
        let nearestDueDayEpoch = dueActions.first.map { epochDay(for: $0.date, calendar: input.calendar) }

        var dueIntents: [DueReminderIntent] = []
        var retryAnchorByEpoch: [Int: Date] = [:]

        for due in baseDueActions {
            let dueDay = input.calendar.startOfDay(for: due.date)
            let dueEpoch = Int(dueDay.timeIntervalSince1970)
            let served = input.servedBaseFireDateByDueDayEpoch[dueEpoch]
            let anchor = originalFirstReminderDate(
                dueDay: dueDay,
                now: input.now,
                reminderHour: input.reminderHour,
                reminderMinute: input.reminderMinute,
                servedBaseFireDate: served,
                scheduleDay: input.scheduleDay,
                calendar: input.calendar
            )
            let firstReminderDate = firstBaseReminderDateForDueAction(
                dueDay: dueDay,
                now: input.now,
                reminderHour: input.reminderHour,
                reminderMinute: input.reminderMinute,
                snoozeOverride: effectiveSnoozeOverride,
                servedBaseFireDate: served,
                scheduleDay: input.scheduleDay,
                calendar: input.calendar
            )

            if let firstReminderDate,
               DoseWindow.isOpen(
                day: dueDay,
                now: firstReminderDate,
                hour: input.reminderHour,
                minute: input.reminderMinute,
                calendar: input.calendar
               ) {
                let firstKind: DueReminderKind = (effectiveSnoozeOverride?.dueDayEpoch == dueEpoch) ? .snooze : .base
                let namesStreak = firstKind == .base
                    && due.method == .pill
                    && due.type.enforcesAdherence
                    && dueEpoch == nearestDueDayEpoch
                    && Self.streakReminderRange.contains(input.currentStreak)
                dueIntents.append(
                    DueReminderIntent(
                        action: due,
                        fireDate: firstReminderDate,
                        dueDayEpoch: dueEpoch,
                        kind: firstKind,
                        streakAtRisk: namesStreak ? input.currentStreak : nil
                    )
                )
            }

            retryAnchorByEpoch[dueEpoch] = dueIntents.last(where: { $0.dueDayEpoch == dueEpoch })?.fireDate ?? anchor
        }

        var plannedIntents = dueIntents

        // Plan follow-ups for every untaken due day up front, since nothing rebuilds
        // when the window rolls over at the next reminder. During a Reverse Trial
        // they stop where its Plus Access ends.
        let trialEnd = trialAccessEnd(input)
        for due in baseDueActions {
            let remainingBudget = dueReminderBudget - plannedIntents.count
            guard remainingBudget > 0 else { break }
            let retries = planRetryReminders(
                for: due,
                retryAnchorByEpoch: retryAnchorByEpoch,
                now: input.now,
                intervalMinutes: input.autoReminderIntervalMinutes,
                retryLimit: effectiveRetryLimit,
                reminderHour: input.reminderHour,
                reminderMinute: input.reminderMinute,
                budget: remainingBudget,
                calendar: input.calendar
            )
            plannedIntents.append(contentsOf: retries.filter { retry in
                trialEnd.map { retry.fireDate < $0 } ?? true
            })
        }

        var intents = Array(plannedIntents.prefix(dueReminderBudget)).map(Intent.due)
        if let supplyIntent {
            intents.append(.supply(supplyIntent))
        }
        if let cycleTransitionIntent {
            intents.append(.cycleTransition(cycleTransitionIntent))
        }
        intents.append(contentsOf: trialWarningIntents.map(Intent.trialExpiryWarning))
        return Array(intents.prefix(Self.maxPendingReminders))
    }

    /// When a hard-paywall user's trial ends, Pillie stops reminding them until
    /// they choose a plan. Grandfathered (legacy) users and subscribers keep
    /// their reminders. Only the trial notices may fire past this moment.
    private func hardPaywallAccessEnd(_ input: Input) -> Date? {
        guard input.trialEndTerms == .hardPaywall else { return nil }
        return trialAccessEnd(input)
    }

    /// When a Reverse Trial's Plus Access ends; `nil` for an entitled user or
    /// one never granted a trial.
    private func trialAccessEnd(_ input: Input) -> Date? {
        guard !input.hasEntitlement, let grantDate = input.trialGrantDate else { return nil }
        return ReverseTrialClock(
            grantDate: grantDate,
            schedule: ActiveDaySchedule(pack: input.pack, calendar: input.calendar)
        ).expiryMoment(calendar: input.calendar)
    }

    /// Plans the Reverse Trial notices (#168 / ADR 0007) from
    /// `trialNoticeSlots`: the day-10 and day-13 warnings at 20:00, 5 and 2
    /// local days before expiry, so copy ("in 5 days", "tomorrow night") stays
    /// true when a break slides expiry, plus the day-15 notice at 10:00 on the
    /// expiry day itself.
    private func planTrialExpiryWarnings(_ input: Input) -> [TrialExpiryWarningIntent] {
        // Entitled users never see expiry pressure: a mid-trial purchase replans
        // and the pending notices fall out of the managed set as stale.
        guard !input.hasEntitlement, let grantDate = input.trialGrantDate else { return [] }

        let clock = ReverseTrialClock(
            grantDate: grantDate,
            schedule: ActiveDaySchedule(pack: input.pack, calendar: input.calendar)
        )
        let expiry = clock.expiryMoment(calendar: input.calendar)
        return Self.trialNoticeSlots.compactMap { slot in
            guard let noticeDay = input.calendar.date(
                byAdding: .day,
                value: -slot.calendarDaysBeforeExpiry,
                to: expiry
            ) else {
                return nil
            }
            let fireDate = reminderDate(
                on: noticeDay,
                hour: slot.hour,
                minute: 0,
                calendar: input.calendar
            )
            // A notice whose moment already passed is never scheduled: an aged
            // or expired trial keeps only notices still ahead of it. (A past
            // calendar trigger would otherwise fire immediately.)
            guard fireDate > input.now else { return nil }
            return TrialExpiryWarningIntent(
                day: slot.day,
                fireDate: fireDate,
                cohort: input.trialCohort,
                terms: input.trialEndTerms
            )
        }
    }

    private func planRetryReminders(
        for due: DoseScheduleAction,
        retryAnchorByEpoch: [Int: Date],
        now: Date,
        intervalMinutes: Int,
        retryLimit: Int,
        reminderHour: Int,
        reminderMinute: Int,
        budget: Int,
        calendar: Calendar
    ) -> [DueReminderIntent] {
        let cappedBudget = min(budget, retryLimit)
        guard cappedBudget > 0 else { return [] }

        let dueDay = calendar.startOfDay(for: due.date)
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        guard let anchor = retryAnchorByEpoch[dueEpoch] else {
            return []
        }

        let windowEnd = DoseWindow.deadline(
            for: dueDay,
            hour: reminderHour,
            minute: reminderMinute,
            calendar: calendar
        ) ?? endOfDayExclusive(for: dueDay, calendar: calendar)
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        var nextFire = anchor.addingTimeInterval(interval)

        var intents: [DueReminderIntent] = []
        while intents.count < cappedBudget && nextFire < windowEnd {
            if nextFire > now {
                intents.append(
                    DueReminderIntent(
                        action: due,
                        fireDate: nextFire,
                        dueDayEpoch: dueEpoch,
                        kind: .retry
                    )
                )
            }
            nextFire.addTimeInterval(interval)
        }

        return intents
    }

    private func planSupplyReminder(_ input: Input) -> SupplyReminderIntent? {
        let today = input.calendar.startOfDay(for: input.scheduleDay)
        let cycleLength = max(1, input.pack.cycleLength)
        let currentDayIndex = input.pack.cycleDayIndex(on: today, calendar: input.calendar)

        let supplyUnitsLeft: Int
        let thresholdDayIndex: Int

        switch input.pack.method {
        case .pill:
            let pillsLeft = min(input.refillReminderThresholdDays, cycleLength)
            supplyUnitsLeft = pillsLeft
            thresholdDayIndex = max(0, cycleLength - pillsLeft)
        case .patch:
            let patchesLeft = input.patchRestockReminderThresholdPatches
            supplyUnitsLeft = patchesLeft
            thresholdDayIndex = patchesLeft == 2 ? 0 : 7 // cycle day 1 or 8
        case .ring:
            return nil
        }

        let deltaToThresholdDay = (thresholdDayIndex - currentDayIndex + cycleLength) % cycleLength

        guard let triggerDay = input.calendar.date(byAdding: .day, value: deltaToThresholdDay, to: today) else {
            return nil
        }

        let fireDate = reminderDate(
            on: triggerDay,
            hour: input.reminderHour,
            minute: input.reminderMinute,
            calendar: input.calendar
        )
        // One-shot, like the Cycle Transition Notice: once the threshold day's
        // reminder moment passes, a rebuild must not turn it into a catch-up
        // that re-fires after every foreground, check-in, or background refresh.
        guard fireDate > input.now else { return nil }

        let dueDayEpoch = Int(input.calendar.startOfDay(for: triggerDay).timeIntervalSince1970)
        return SupplyReminderIntent(
            fireDate: fireDate,
            dueDayEpoch: dueDayEpoch,
            supplyUnitsLeft: supplyUnitsLeft,
            method: input.pack.method
        )
    }

    /// Plans the free Cycle Transition Notice (#123) for the next break/off week.
    ///
    /// Scans forward from today for the first active→break boundary (a silent break day
    /// while the previous day is not), which lands on the first pill-free day for a
    /// no-pill pack and the first off-week day after removal for the patch/ring. A
    /// sugar-pill break keeps its daily reminder, so it gets no notice. The
    /// notice fires at the user's reminder time on that day and never coincides with an
    /// active-phase / new-pack start (those are active days, already covered by a Due
    /// Action Reminder). Continuous regimens with no break week (e.g. 28/0, 365/0) get
    /// no notice.
    private func planCycleTransitionNotice(_ input: Input) -> CycleTransitionIntent? {
        guard input.cycleTransitionEnabled else { return nil }
        guard input.pack.breakDays > 0 else { return nil }

        let calendar = input.calendar
        let cycleLength = max(1, input.pack.cycleLength)
        let today = calendar.startOfDay(for: input.scheduleDay)

        // Look up to ~two cycles ahead so the boundary is always reachable regardless of
        // where in the cycle "today" falls.
        let scanLimit = cycleLength * 2 + 2

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
        var previousIsBreak = isSilentBreakDay(yesterday, pack: input.pack, calendar: calendar)

        var cursor = today
        var transitionDay: Date?
        for _ in 0..<scanLimit {
            let currentIsBreak = isSilentBreakDay(cursor, pack: input.pack, calendar: calendar)
            if currentIsBreak && !previousIsBreak {
                transitionDay = cursor
                break
            }
            previousIsBreak = currentIsBreak
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        guard let transitionDay else { return nil }

        let fireDate = reminderDate(
            on: transitionDay,
            hour: input.reminderHour,
            minute: input.reminderMinute,
            calendar: calendar
        )
        // This is a one-shot informational notice, not a due action. Once its scheduled
        // moment passes, a later app-driven rebuild must not turn it into a catch-up
        // reminder and re-fire it throughout the transition day.
        guard fireDate > input.now,
              fireDate < endOfDayExclusive(for: transitionDay, calendar: calendar) else {
            return nil
        }

        guard let resumeDate = firstActiveDay(
            after: transitionDay,
            pack: input.pack,
            calendar: calendar,
            withinDays: cycleLength + 1
        ) else {
            return nil
        }

        return CycleTransitionIntent(
            transitionDayEpoch: Int(transitionDay.timeIntervalSince1970),
            fireDate: fireDate,
            method: input.pack.method,
            resumeDate: resumeDate
        )
    }

    /// A break day with nothing due. A sugar-pill day keeps its Due Action
    /// Reminder, so a sugar break has no silence to explain.
    private func isSilentBreakDay(_ date: Date, pack: PillPack, calendar: Calendar) -> Bool {
        guard let action = DoseScheduleEngine.dueAction(on: date, pack: pack, calendar: calendar) else { return false }
        return action.isBreak && !action.type.requiresUserAction
    }

    /// First non-break (active-phase) day strictly after `day`, i.e. the day the active
    /// phase resumes. Scans at most `withinDays` days forward.
    private func firstActiveDay(after day: Date, pack: PillPack, calendar: Calendar, withinDays: Int) -> Date? {
        var cursor = day
        for _ in 0..<max(0, withinDays) {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
            if !isSilentBreakDay(cursor, pack: pack, calendar: calendar) {
                return cursor
            }
        }
        return nil
    }

    private func firstBaseReminderDateForDueAction(
        dueDay: Date,
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        snoozeOverride: SnoozeOverride?,
        servedBaseFireDate: Date?,
        scheduleDay: Date,
        calendar: Calendar
    ) -> Date? {
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        if let snoozeOverride,
           snoozeOverride.dueDayEpoch == dueEpoch {
            return max(snoozeOverride.firstFireDate, now.addingTimeInterval(1))
        }

        let configured = reminderDate(on: dueDay, hour: reminderHour, minute: reminderMinute, calendar: calendar)
        let windowEnd = DoseWindow.deadline(
            for: dueDay,
            hour: reminderHour,
            minute: reminderMinute,
            calendar: calendar
        ) ?? endOfDayExclusive(for: dueDay, calendar: calendar)

        guard isCatchUpTerritory(
            dueDay: dueDay,
            now: now,
            configuredFireDate: configured,
            scheduleDay: scheduleDay,
            calendar: calendar
        ) else {
            return configured
        }

        let catchUp = now.addingTimeInterval(TimeInterval(Self.catchupDelayMinutes * 60))
        // A catch-up is planned at most a minute out, so a served base later than
        // that is still pending at an older, later reminder time. That time no
        // longer applies, so the day catches up instead.
        if let served = servedBaseFireDate, served <= catchUp {
            if served <= now { return nil }
            if served < windowEnd { return served }
            return nil
        }

        return catchUp
    }

    /// The day's original first-reminder moment, anchoring retry cadence. Outside
    /// catch-up territory this is the configured time.
    private func originalFirstReminderDate(
        dueDay: Date,
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        servedBaseFireDate: Date?,
        scheduleDay: Date,
        calendar: Calendar
    ) -> Date {
        let configured = reminderDate(on: dueDay, hour: reminderHour, minute: reminderMinute, calendar: calendar)
        if let servedBaseFireDate,
           isCatchUpTerritory(
            dueDay: dueDay,
            now: now,
            configuredFireDate: configured,
            scheduleDay: scheduleDay,
            calendar: calendar
           ) {
            return servedBaseFireDate
        }
        return configured
    }

    /// Catch-up territory is the live dose day after that day's reminder has passed.
    private func isCatchUpTerritory(
        dueDay: Date,
        now: Date,
        configuredFireDate: Date,
        scheduleDay: Date,
        calendar: Calendar
    ) -> Bool {
        calendar.isDate(dueDay, inSameDayAs: scheduleDay) && configuredFireDate <= now
    }

    private func reminderDate(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? day
    }

    private func endOfDayExclusive(for day: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 60 * 60)
    }

    private func epochDay(for date: Date, calendar: Calendar) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }
}

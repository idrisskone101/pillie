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
    /// Minimum spacing between the day's first Due Action Reminder and the Last Call
    /// re-fire. If the configured Last Call time is closer than this to the reminder
    /// time, the Last Call is suppressed for that day so it stays a meaningful backstop.
    static let lastCallMinimumGapMinutes = 60
    /// An Auto-Reminder Retry firing within this window of the Last Call is dropped so
    /// the two never arrive back-to-back.
    static let lastCallRetryGuardMinutes = 15
    /// Reverse Trial expiry warnings (#168 / ADR 0007) fire on these trial days,
    /// counting the grant day as day 0 — the same clock as `ReverseTrialClock`,
    /// whose expiry lands at the local-day rollover after day 14.
    static let trialWarningDays = [10, 13]
    /// Local hour the trial expiry warnings fire at: early evening, decoupled from
    /// the user's Due Action Reminder time and ahead of the 9 PM Last Call default
    /// so the informational nudge never stacks on an action reminder.
    static let trialWarningHour = 19

    enum DueReminderKind: String {
        case base
        case retry
        case snooze
        case lastCall
    }

    struct SnoozeOverride {
        let dueDayEpoch: Int
        let firstFireDate: Date
    }

    struct Input {
        let now: Date
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
        /// Whether the Last Call Reminder (a single end-of-day re-fire of the Due Action
        /// Reminder, fired only while the action is still untaken) is enabled. Like the
        /// rest of Smart Reminders it is gated by `smartRemindersEnabled`: forced off for
        /// free users (ADR 0004). Fires independently of the Auto-Reminder Retry cadence.
        let lastCallEnabled: Bool
        /// Configured Last Call time-of-day (local). Default 9:00 PM.
        let lastCallHour: Int
        let lastCallMinute: Int
        /// The Reverse Trial grant moment, if any (ADR 0007). Drives the day-10/13
        /// expiry warnings (#168); `nil` when no trial was ever granted.
        let trialGrantDate: Date?
        /// The raw Plus entitlement — NOT `hasPlusAccess`, which is true during the
        /// trial itself. Entitled users get no expiry warnings: a mid-trial purchase
        /// replans and both pending warnings fall out as stale.
        let hasEntitlement: Bool
        let calendar: Calendar
    }

    struct DueReminderIntent: Hashable {
        let action: DoseScheduleAction
        let fireDate: Date
        let dueDayEpoch: Int
        let kind: DueReminderKind
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

    /// A Reverse Trial expiry warning (#168): a plain informational local
    /// notification on trial day 10 and day 13 saying when app blocking turns
    /// off. Not a Smart Reminder — never gated by Plus, never a re-fire.
    struct TrialExpiryWarningIntent: Hashable {
        /// Trial day the warning fires on (10 or 13), grant day = day 0.
        let day: Int
        let fireDate: Date
    }

    enum Intent: Hashable {
        case due(DueReminderIntent)
        case supply(SupplyReminderIntent)
        case cycleTransition(CycleTransitionIntent)
        case trialExpiryWarning(TrialExpiryWarningIntent)
    }

    func planReminders(_ input: Input) -> [Intent] {
        // Smart Reminders gating: free users keep exactly one Due Action Reminder
        // with no auto-retries and no snooze re-fire. Supply reminders are planned
        // separately below and are unaffected. The stored settings are read but not
        // mutated (ADR 0004).
        let effectiveRetryLimit = input.smartRemindersEnabled ? input.autoReminderRetryLimit : 0
        let effectiveSnoozeOverride = input.smartRemindersEnabled ? input.snoozeOverride : nil
        // Last Call is a Smart Reminders perk: forced off for free users (ADR 0004),
        // independent of the retry limit.
        let lastCallEnabled = input.smartRemindersEnabled && input.lastCallEnabled

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
            let key = epochDay(for: action.date, calendar: input.calendar)
            return input.statusByEpochDay[key] != .taken
        }
        let baseDueActions = Array(dueActions.prefix(min(Self.baseReminderCount, dueReminderBudget)))

        var dueIntents: [DueReminderIntent] = []
        var lastCallIntents: [DueReminderIntent] = []
        var firstReminderByEpoch: [Int: Date] = [:]
        var lastCallByEpoch: [Int: Date] = [:]

        for due in baseDueActions {
            let dueDay = input.calendar.startOfDay(for: due.date)
            let dueEpoch = Int(dueDay.timeIntervalSince1970)
            let firstReminderDate = firstReminderDateForDueAction(
                dueDay: dueDay,
                now: input.now,
                reminderHour: input.reminderHour,
                reminderMinute: input.reminderMinute,
                snoozeOverride: effectiveSnoozeOverride,
                calendar: input.calendar
            )

            guard let firstReminderDate,
                  firstReminderDate < endOfDayExclusive(for: dueDay, calendar: input.calendar) else {
                continue
            }

            let firstKind: DueReminderKind = (effectiveSnoozeOverride?.dueDayEpoch == dueEpoch) ? .snooze : .base
            dueIntents.append(
                DueReminderIntent(
                    action: due,
                    fireDate: firstReminderDate,
                    dueDayEpoch: dueEpoch,
                    kind: firstKind
                )
            )
            firstReminderByEpoch[dueEpoch] = firstReminderDate

            // At most one Last Call per untaken due-action day, only when it sits at
            // least `lastCallMinimumGapMinutes` after the day's first reminder.
            if lastCallEnabled,
               let lastCallDate = lastCallDateForDueDay(
                   dueDay: dueDay,
                   firstReminderDate: firstReminderDate,
                   now: input.now,
                   lastCallHour: input.lastCallHour,
                   lastCallMinute: input.lastCallMinute,
                   calendar: input.calendar
               ) {
                lastCallByEpoch[dueEpoch] = lastCallDate
                lastCallIntents.append(
                    DueReminderIntent(
                        action: due,
                        fireDate: lastCallDate,
                        dueDayEpoch: dueEpoch,
                        kind: .lastCall
                    )
                )
            }
        }

        var plannedIntents = dueIntents + lastCallIntents

        let remainingBudget = max(0, dueReminderBudget - plannedIntents.count)
        if remainingBudget > 0,
           let nearestDue = dueActions.first {
            let retries = planRetryReminders(
                for: nearestDue,
                firstReminderByEpoch: firstReminderByEpoch,
                now: input.now,
                intervalMinutes: input.autoReminderIntervalMinutes,
                retryLimit: effectiveRetryLimit,
                budget: remainingBudget,
                reminderHour: input.reminderHour,
                reminderMinute: input.reminderMinute,
                snoozeOverride: effectiveSnoozeOverride,
                calendar: input.calendar
            )
            // Drop any retry that would land within the guard window of the Last Call so
            // the two never arrive back-to-back.
            let guardInterval = TimeInterval(Self.lastCallRetryGuardMinutes * 60)
            let deduped = retries.filter { retry in
                guard let lastCall = lastCallByEpoch[retry.dueDayEpoch] else { return true }
                return abs(retry.fireDate.timeIntervalSince(lastCall)) > guardInterval
            }
            plannedIntents.append(contentsOf: deduped)
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

    /// Plans the Reverse Trial day-10/13 expiry warnings (#168 / ADR 0007):
    /// scheduled at grant, anchored to the grant day (day 0) so the fire days
    /// agree with `ReverseTrialClock`'s midnight-after-day-14 expiry.
    private func planTrialExpiryWarnings(_ input: Input) -> [TrialExpiryWarningIntent] {
        // Entitled users never see expiry pressure: a mid-trial purchase replans
        // and both pending warnings fall out of the managed set as stale.
        guard !input.hasEntitlement, let grantDate = input.trialGrantDate else { return [] }

        let grantDayStart = input.calendar.startOfDay(for: grantDate)
        return Self.trialWarningDays.compactMap { day in
            guard let warningDay = input.calendar.date(byAdding: .day, value: day, to: grantDayStart) else {
                return nil
            }
            let fireDate = reminderDate(on: warningDay, hour: Self.trialWarningHour, minute: 0, calendar: input.calendar)
            // A warning whose moment already passed is never scheduled — an aged
            // or expired trial keeps only warnings still ahead of it. (A past
            // calendar trigger would otherwise fire immediately.)
            guard fireDate > input.now else { return nil }
            return TrialExpiryWarningIntent(day: day, fireDate: fireDate)
        }
    }

    private func planRetryReminders(
        for due: DoseScheduleAction,
        firstReminderByEpoch: [Int: Date],
        now: Date,
        intervalMinutes: Int,
        retryLimit: Int,
        budget: Int,
        reminderHour: Int,
        reminderMinute: Int,
        snoozeOverride: SnoozeOverride?,
        calendar: Calendar
    ) -> [DueReminderIntent] {
        let cappedBudget = min(budget, retryLimit)
        guard cappedBudget > 0 else { return [] }

        let dueDay = calendar.startOfDay(for: due.date)
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        guard let firstReminderDate = firstReminderByEpoch[dueEpoch]
            ?? firstReminderDateForDueAction(
                dueDay: dueDay,
                now: now,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                snoozeOverride: snoozeOverride,
                calendar: calendar
            ) else {
            return []
        }

        let dayEnd = endOfDayExclusive(for: dueDay, calendar: calendar)
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        var nextFire = firstReminderDate.addingTimeInterval(interval)

        var intents: [DueReminderIntent] = []
        while intents.count < cappedBudget && nextFire < dayEnd {
            intents.append(
                DueReminderIntent(
                    action: due,
                    fireDate: nextFire,
                    dueDayEpoch: dueEpoch,
                    kind: .retry
                )
            )
            nextFire.addTimeInterval(interval)
        }

        return intents
    }

    private func planSupplyReminder(_ input: Input) -> SupplyReminderIntent? {
        let today = input.calendar.startOfDay(for: input.now)
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

        guard let fireDate = firstReminderDateForDueAction(
            dueDay: triggerDay,
            now: input.now,
            reminderHour: input.reminderHour,
            reminderMinute: input.reminderMinute,
            snoozeOverride: nil,
            calendar: input.calendar
        ),
        fireDate < endOfDayExclusive(for: triggerDay, calendar: input.calendar) else {
            return nil
        }

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
    /// Scans forward from today for the first active→break boundary (a day whose action
    /// is a break type while the previous day is not), which lands on the first placebo
    /// day for the pill and the first off-week day after removal for the patch/ring. The
    /// notice fires at the user's reminder time on that day and never coincides with an
    /// active-phase / new-pack start (those are active days, already covered by a Due
    /// Action Reminder). Continuous regimens with no break week (e.g. 28/0, 365/0) get
    /// no notice.
    private func planCycleTransitionNotice(_ input: Input) -> CycleTransitionIntent? {
        guard input.cycleTransitionEnabled else { return nil }
        guard input.pack.breakDays > 0 else { return nil }

        let calendar = input.calendar
        let cycleLength = max(1, input.pack.cycleLength)
        let today = calendar.startOfDay(for: input.now)

        // Look up to ~two cycles ahead so the boundary is always reachable regardless of
        // where in the cycle "today" falls.
        let scanLimit = cycleLength * 2 + 2

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
        var previousIsBreak = isBreakDay(yesterday, pack: input.pack, calendar: calendar)

        var cursor = today
        var transitionDay: Date?
        for _ in 0..<scanLimit {
            let currentIsBreak = isBreakDay(cursor, pack: input.pack, calendar: calendar)
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

    private func isBreakDay(_ date: Date, pack: PillPack, calendar: Calendar) -> Bool {
        DoseScheduleEngine.dueAction(on: date, pack: pack, calendar: calendar)?.isBreak ?? false
    }

    /// First non-break (active-phase) day strictly after `day`, i.e. the day the active
    /// phase resumes. Scans at most `withinDays` days forward.
    private func firstActiveDay(after day: Date, pack: PillPack, calendar: Calendar, withinDays: Int) -> Date? {
        var cursor = day
        for _ in 0..<max(0, withinDays) {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
            if !isBreakDay(cursor, pack: pack, calendar: calendar) {
                return cursor
            }
        }
        return nil
    }

    private func firstReminderDateForDueAction(
        dueDay: Date,
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        snoozeOverride: SnoozeOverride?,
        calendar: Calendar
    ) -> Date? {
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        if let snoozeOverride,
           snoozeOverride.dueDayEpoch == dueEpoch {
            return max(snoozeOverride.firstFireDate, now.addingTimeInterval(1))
        }

        let configured = reminderDate(on: dueDay, hour: reminderHour, minute: reminderMinute, calendar: calendar)

        if calendar.isDate(dueDay, inSameDayAs: now), configured <= now {
            return now.addingTimeInterval(TimeInterval(Self.catchupDelayMinutes * 60))
        }

        return configured
    }

    /// The Last Call fire date for a due-action day, or nil when it should be suppressed.
    /// Suppressed when the configured time is in the past, falls outside the due day, or
    /// is less than `lastCallMinimumGapMinutes` after the day's first reminder.
    private func lastCallDateForDueDay(
        dueDay: Date,
        firstReminderDate: Date,
        now: Date,
        lastCallHour: Int,
        lastCallMinute: Int,
        calendar: Calendar
    ) -> Date? {
        let configured = reminderDate(on: dueDay, hour: lastCallHour, minute: lastCallMinute, calendar: calendar)

        guard configured > now,
              configured < endOfDayExclusive(for: dueDay, calendar: calendar) else {
            return nil
        }

        let minimumGap = TimeInterval(Self.lastCallMinimumGapMinutes * 60)
        guard configured.timeIntervalSince(firstReminderDate) >= minimumGap else {
            return nil
        }

        return configured
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

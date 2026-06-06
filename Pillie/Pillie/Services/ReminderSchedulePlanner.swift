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

    enum Intent: Hashable {
        case due(DueReminderIntent)
        case supply(SupplyReminderIntent)
    }

    func planReminders(_ input: Input) -> [Intent] {
        let supplyIntent = planSupplyReminder(input)
        let dueReminderBudget = max(0, Self.maxPendingReminders - (supplyIntent == nil ? 0 : 1))
        guard dueReminderBudget > 0 else {
            return supplyIntent.map { [.supply($0)] } ?? []
        }

        let dueActions = input.candidateDueActions.filter { action in
            let key = epochDay(for: action.date, calendar: input.calendar)
            return input.statusByEpochDay[key] != .taken
        }
        let baseDueActions = Array(dueActions.prefix(min(Self.baseReminderCount, dueReminderBudget)))

        var dueIntents: [DueReminderIntent] = []
        var firstReminderByEpoch: [Int: Date] = [:]

        for due in baseDueActions {
            let dueDay = input.calendar.startOfDay(for: due.date)
            let dueEpoch = Int(dueDay.timeIntervalSince1970)
            let firstReminderDate = firstReminderDateForDueAction(
                dueDay: dueDay,
                now: input.now,
                reminderHour: input.reminderHour,
                reminderMinute: input.reminderMinute,
                snoozeOverride: input.snoozeOverride,
                calendar: input.calendar
            )

            guard let firstReminderDate,
                  firstReminderDate < endOfDayExclusive(for: dueDay, calendar: input.calendar) else {
                continue
            }

            let firstKind: DueReminderKind = (input.snoozeOverride?.dueDayEpoch == dueEpoch) ? .snooze : .base
            dueIntents.append(
                DueReminderIntent(
                    action: due,
                    fireDate: firstReminderDate,
                    dueDayEpoch: dueEpoch,
                    kind: firstKind
                )
            )
            firstReminderByEpoch[dueEpoch] = firstReminderDate
        }

        let remainingBudget = max(0, dueReminderBudget - dueIntents.count)
        if remainingBudget > 0,
           let nearestDue = dueActions.first {
            dueIntents.append(
                contentsOf: planRetryReminders(
                    for: nearestDue,
                    firstReminderByEpoch: firstReminderByEpoch,
                    now: input.now,
                    intervalMinutes: input.autoReminderIntervalMinutes,
                    retryLimit: input.autoReminderRetryLimit,
                    budget: remainingBudget,
                    reminderHour: input.reminderHour,
                    reminderMinute: input.reminderMinute,
                    snoozeOverride: input.snoozeOverride,
                    calendar: input.calendar
                )
            )
        }

        var intents = Array(dueIntents.prefix(dueReminderBudget)).map(Intent.due)
        if let supplyIntent {
            intents.append(.supply(supplyIntent))
        }
        return Array(intents.prefix(Self.maxPendingReminders))
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

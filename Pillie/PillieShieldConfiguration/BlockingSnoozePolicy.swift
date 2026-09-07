//
//  BlockingSnoozePolicy.swift
//  Keep byte-identical with Pillie/Services/BlockingSnoozePolicy.swift
//
//  One blocking snooze per due-day instance, three per calendar month.
//

import Foundation

struct BlockingSnoozeLedger: Codable, Equatable, Sendable {
    var monthStartEpochDay: Int
    var usedDueDayEpochs: [Int]

    static let empty = BlockingSnoozeLedger(monthStartEpochDay: 0, usedDueDayEpochs: [])
}

enum BlockingSnoozeRejection: Equatable, Sendable {
    case alreadyUsedThisInstance
    case monthlyCapReached
}

enum BlockingSnoozeAttempt: Equatable, Sendable {
    case accepted(until: Date, remainingThisMonth: Int)
    case rejected(BlockingSnoozeRejection)
}

enum BlockingSnoozePolicy {
    static let monthlyLimit = 3
    static let intervalOptions = [15, 30, 60]
    static let defaultIntervalMinutes = 30

    static func normalizedInterval(_ value: Int) -> Int {
        intervalOptions.contains(value) ? value : defaultIntervalMinutes
    }

    static func monthStartEpochDay(for now: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        return Int(calendar.startOfDay(for: start).timeIntervalSince1970)
    }

    static func rolled(
        _ ledger: BlockingSnoozeLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> BlockingSnoozeLedger {
        let monthStart = monthStartEpochDay(for: now, calendar: calendar)
        guard ledger.monthStartEpochDay == monthStart else {
            return BlockingSnoozeLedger(monthStartEpochDay: monthStart, usedDueDayEpochs: [])
        }
        return ledger
    }

    static func remaining(
        ledger: BlockingSnoozeLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let current = rolled(ledger, now: now, calendar: calendar)
        return max(0, monthlyLimit - Set(current.usedDueDayEpochs).count)
    }

    static func canAccept(
        ledger: BlockingSnoozeLedger,
        dueDayEpoch: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let current = rolled(ledger, now: now, calendar: calendar)
        let used = Set(current.usedDueDayEpochs)
        return !used.contains(dueDayEpoch) && used.count < monthlyLimit
    }

    static func isHoldActive(until: Date?, now: Date) -> Bool {
        guard let until else { return false }
        return now < until
    }

    static func attempt(
        ledger: BlockingSnoozeLedger,
        dueDayEpoch: Int,
        now: Date,
        intervalMinutes: Int,
        calendar: Calendar = .current
    ) -> (ledger: BlockingSnoozeLedger, result: BlockingSnoozeAttempt) {
        var current = rolled(ledger, now: now, calendar: calendar)
        let used = Set(current.usedDueDayEpochs)

        if used.contains(dueDayEpoch) {
            return (current, .rejected(.alreadyUsedThisInstance))
        }
        if used.count >= monthlyLimit {
            return (current, .rejected(.monthlyCapReached))
        }

        current.usedDueDayEpochs = (used + [dueDayEpoch]).sorted()
        let remainingThisMonth = max(0, monthlyLimit - current.usedDueDayEpochs.count)
        let until = untilDate(from: now, intervalMinutes: intervalMinutes, calendar: calendar)
        return (current, .accepted(until: until, remainingThisMonth: remainingThisMonth))
    }

    static func untilDate(
        from now: Date,
        intervalMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        let delay = TimeInterval(max(1, intervalMinutes) * 60)
        let proposed = now.addingTimeInterval(delay)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? proposed
        return min(proposed, endOfDay)
    }
}

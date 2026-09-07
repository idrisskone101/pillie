import Foundation
import Testing

@testable import Pillie

struct BlockingSnoozePolicyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    @Test func `First snooze this month is accepted and leaves two remaining`() {
        let now = date(2026, 9, 6, hour: 8, minute: 5)
        let due = epochDay(2026, 9, 6)
        let outcome = BlockingSnoozePolicy.attempt(
            ledger: .empty,
            dueDayEpoch: due,
            now: now,
            intervalMinutes: 10,
            calendar: calendar
        )

        #expect(outcome.ledger.usedDueDayEpochs == [due])
        #expect(outcome.ledger.monthStartEpochDay == BlockingSnoozePolicy.monthStartEpochDay(
            for: now,
            calendar: calendar
        ))
        guard case .accepted(let until, let remaining) = outcome.result else {
            Issue.record("expected accepted snooze")
            return
        }
        #expect(remaining == 2)
        #expect(until == now.addingTimeInterval(10 * 60))
    }

    @Test func `Same due day cannot be snoozed again`() {
        let now = date(2026, 9, 6, hour: 8, minute: 5)
        let due = epochDay(2026, 9, 6)
        let first = BlockingSnoozePolicy.attempt(
            ledger: .empty,
            dueDayEpoch: due,
            now: now,
            intervalMinutes: 10,
            calendar: calendar
        )
        let second = BlockingSnoozePolicy.attempt(
            ledger: first.ledger,
            dueDayEpoch: due,
            now: now.addingTimeInterval(12 * 60),
            intervalMinutes: 10,
            calendar: calendar
        )

        #expect(second.result == .rejected(.alreadyUsedThisInstance))
        #expect(second.ledger.usedDueDayEpochs == [due])
    }

    @Test func `Fourth distinct day in the same month is rejected`() {
        let now = date(2026, 9, 20, hour: 8)
        var ledger = BlockingSnoozeLedger.empty
        for day in [6, 10, 14] {
            let outcome = BlockingSnoozePolicy.attempt(
                ledger: ledger,
                dueDayEpoch: epochDay(2026, 9, day),
                now: date(2026, 9, day, hour: 8),
                intervalMinutes: 10,
                calendar: calendar
            )
            ledger = outcome.ledger
            guard case .accepted = outcome.result else {
                Issue.record("day \(day) should be accepted")
                return
            }
        }

        let fourth = BlockingSnoozePolicy.attempt(
            ledger: ledger,
            dueDayEpoch: epochDay(2026, 9, 20),
            now: now,
            intervalMinutes: 10,
            calendar: calendar
        )
        #expect(fourth.result == .rejected(.monthlyCapReached))
        #expect(BlockingSnoozePolicy.remaining(ledger: ledger, now: now, calendar: calendar) == 0)
    }

    @Test func `Calendar month roll resets the quota`() {
        let september = BlockingSnoozePolicy.attempt(
            ledger: .empty,
            dueDayEpoch: epochDay(2026, 9, 30),
            now: date(2026, 9, 30, hour: 8),
            intervalMinutes: 10,
            calendar: calendar
        )
        let october = BlockingSnoozePolicy.attempt(
            ledger: september.ledger,
            dueDayEpoch: epochDay(2026, 10, 1),
            now: date(2026, 10, 1, hour: 8),
            intervalMinutes: 10,
            calendar: calendar
        )

        #expect(october.ledger.usedDueDayEpochs == [epochDay(2026, 10, 1)])
        guard case .accepted(_, let remaining) = october.result else {
            Issue.record("expected October snooze to be accepted")
            return
        }
        #expect(remaining == 2)
    }

    @Test func `Unknown interval falls back to thirty minutes`() {
        #expect(BlockingSnoozePolicy.normalizedInterval(10) == 30)
        #expect(BlockingSnoozePolicy.normalizedInterval(15) == 30)
        #expect(BlockingSnoozePolicy.normalizedInterval(60) == 60)
        #expect(BlockingSnoozePolicy.normalizedInterval(180) == 180)
        #expect(BlockingSnoozePolicy.hourCount(fromMinutes: 30) == nil)
        #expect(BlockingSnoozePolicy.hourCount(fromMinutes: 60) == 1)
        #expect(BlockingSnoozePolicy.hourCount(fromMinutes: 180) == 3)
        #expect(
            BlockingSnoozePolicy.formattedDuration(
                minutes: 30,
                minutesFormat: "%lld minutes",
                hour: "1 hour",
                hoursFormat: "%lld hours",
                locale: Locale(identifier: "en")
            ) == "30 minutes"
        )
        #expect(
            BlockingSnoozePolicy.formattedDuration(
                minutes: 60,
                minutesFormat: "%lld minutes",
                hour: "1 hour",
                hoursFormat: "%lld hours",
                locale: Locale(identifier: "en")
            ) == "1 hour"
        )
        #expect(
            BlockingSnoozePolicy.formattedDuration(
                minutes: 120,
                minutesFormat: "%lld minutes",
                hour: "1 hour",
                hoursFormat: "%lld hours",
                locale: Locale(identifier: "en")
            ) == "2 hours"
        )
    }

    @Test func `Hold is active only before the until date`() {
        let until = date(2026, 9, 6, hour: 8, minute: 15)
        #expect(BlockingSnoozePolicy.isHoldActive(until: until, now: date(2026, 9, 6, hour: 8, minute: 14)))
        #expect(!BlockingSnoozePolicy.isHoldActive(until: until, now: until))
        #expect(!BlockingSnoozePolicy.isHoldActive(until: nil, now: until))
    }

    @Test func `Late-night snooze does not cross midnight`() {
        let now = date(2026, 9, 6, hour: 23, minute: 55)
        let until = BlockingSnoozePolicy.untilDate(from: now, intervalMinutes: 10, calendar: calendar)
        #expect(until == date(2026, 9, 7, hour: 0, minute: 0))
    }

    @Test func `Intervention policy clears shields during a snooze hold`() {
        let now = date(2026, 9, 6, hour: 8, minute: 5)
        let until = now.addingTimeInterval(10 * 60)
        let schedule = BlockingScheduleMirror(
            anchorDate: date(2026, 9, 1, hour: 12),
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: Array(0..<21)
        )

        #expect(
            BlockingInterventionPolicy.decision(
                schedule: schedule,
                handledStamp: TodayTakenStamp(isTaken: false, epochDay: nil),
                now: now,
                calendar: calendar,
                snoozeUntil: until
            ) == .clearShields
        )
        #expect(
            BlockingInterventionPolicy.decision(
                schedule: schedule,
                handledStamp: TodayTakenStamp(isTaken: false, epochDay: nil),
                now: until,
                calendar: calendar,
                snoozeUntil: until
            ) == .applyShields
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func epochDay(_ year: Int, _ month: Int, _ day: Int) -> Int {
        Int(calendar.startOfDay(for: date(year, month, day)).timeIntervalSince1970)
    }
}

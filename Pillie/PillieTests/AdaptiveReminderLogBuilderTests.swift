//
//  AdaptiveReminderLogBuilderTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest dependency).
//

import XCTest
@testable import Pillie

final class AdaptiveReminderLogBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: d, hour: 0))!
    }

    func testSkipsRecordsWithoutATakenTimestamp() {
        let records: [(date: Date, takenAt: Date?)] = [
            (date: day(1), takenAt: nil),
            (date: day(2), takenAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 8, minute: 45))!),
            (date: day(3), takenAt: nil)
        ]

        let logs = AdaptiveReminderLogBuilder.logs(
            from: records,
            reminderHour: 8,
            reminderMinute: 0,
            calendar: calendar
        )

        XCTAssertEqual(logs.count, 1)
    }

    func testAnchorsScheduledReminderToTheReminderTimeOnEachDay() {
        let taken = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 8, minute: 45))!
        let records: [(date: Date, takenAt: Date?)] = [
            // A non-midnight `date` should still anchor to the start of the day.
            (date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 23))!, takenAt: taken)
        ]

        let logs = AdaptiveReminderLogBuilder.logs(
            from: records,
            reminderHour: 8,
            reminderMinute: 0,
            calendar: calendar
        )

        let expectedScheduled = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 8, minute: 0))!
        XCTAssertEqual(logs.first?.scheduledReminder, expectedScheduled)
        XCTAssertEqual(logs.first?.takenAt, taken)
    }

    func testFeedsTheAnalyzerToProduceASuggestion() {
        // 12 days, all logged ~45 minutes after an 8:00 reminder.
        let records: [(date: Date, takenAt: Date?)] = (1...12).map { offset in
            let date = day(offset)
            let taken = calendar.date(from: DateComponents(year: 2026, month: 6, day: offset, hour: 8, minute: 45))!
            return (date: date, takenAt: taken)
        }

        let logs = AdaptiveReminderLogBuilder.logs(
            from: records,
            reminderHour: 8,
            reminderMinute: 0,
            calendar: calendar
        )

        let suggestion = AdaptiveReminderTimeAnalyzer().suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 9))!,
            lastDismissal: nil
        )

        XCTAssertEqual(suggestion?.deltaMinutes, 45)
        XCTAssertEqual(suggestion?.hour, 8)
        XCTAssertEqual(suggestion?.minute, 45)
    }
}

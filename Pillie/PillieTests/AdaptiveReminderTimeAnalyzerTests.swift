//
//  AdaptiveReminderTimeAnalyzerTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest dependency).
//

import XCTest
@testable import Pillie

final class AdaptiveReminderTimeAnalyzerTests: XCTestCase {

    private let analyzer = AdaptiveReminderTimeAnalyzer()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    /// Builds a `(scheduledReminder, takenAt)` log where the scheduled reminder is
    /// at `8:00` on the given day offset and the action was taken `offsetMinutes`
    /// later (negative = earlier).
    private func log(dayOffset: Int, offsetMinutes: Double, reminderHour: Int = 8) -> (scheduledReminder: Date, takenAt: Date) {
        let base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: reminderHour))!
        let scheduled = calendar.date(byAdding: .day, value: dayOffset, to: base)!
        let taken = scheduled.addingTimeInterval(offsetMinutes * 60)
        return (scheduled, taken)
    }

    private func now(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 9))!
    }

    // MARK: - Suggests on consistent late offset

    func testSuggestsShiftWhenConsistentlyLateWithLowVariance() {
        // 12 logs, all ~45 minutes late with small jitter.
        let jitter: [Double] = [44, 46, 45, 47, 43, 45, 46, 44, 45, 47, 43, 46]
        let logs = jitter.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.deltaMinutes, 45)
        XCTAssertEqual(suggestion?.hour, 8)
        XCTAssertEqual(suggestion?.minute, 45)
    }

    func testRoundsSuggestedTimeToNearestFiveMinutes() {
        // Median offset of 47 should round the delta to 45 (nearest 5).
        let offsets: [Double] = [47, 47, 47, 47, 47, 47, 47, 47, 47, 47]
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertEqual(suggestion?.deltaMinutes, 45)
        XCTAssertEqual(suggestion?.minute, 45)
        // Rounded to a multiple of five minutes.
        XCTAssertEqual((suggestion?.deltaMinutes ?? 1) % 5, 0)
    }

    func testSuggestsEarlierShiftWhenConsistentlyEarly() {
        let offsets: [Double] = [-40, -42, -38, -41, -39, -40, -42, -38, -40, -41]
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertEqual(suggestion?.deltaMinutes, -40)
        XCTAssertEqual(suggestion?.hour, 7)
        XCTAssertEqual(suggestion?.minute, 20)
    }

    // MARK: - Returns nil

    func testReturnsNilWhenVarianceIsHigh() {
        // Median is still ~45 but offsets are wildly spread (high IQR).
        let offsets: [Double] = [-30, 120, 5, 90, 45, -10, 150, 0, 60, 100]
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertNil(suggestion)
    }

    func testReturnsNilWhenOffsetBelowThreshold() {
        // Consistent, low variance, but only ~15 minutes late — below 30.
        let offsets: [Double] = [14, 15, 16, 15, 14, 16, 15, 15, 14, 16]
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertNil(suggestion)
    }

    func testReturnsNilWhenFewerThanMinimumLogs() {
        // Only 9 logs (< minimum 10), even though consistently late.
        let offsets: [Double] = Array(repeating: 45, count: 9)
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertNil(suggestion)
    }

    func testReturnsNilDuringCooldownWindowAfterDismissal() {
        let offsets: [Double] = Array(repeating: 45, count: 12)
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }
        let dismissal = now(15)

        // Five days later is still inside the ~14-day cooldown.
        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: now(20),
            lastDismissal: dismissal
        )

        XCTAssertNil(suggestion)
    }

    func testSuggestsAgainAfterCooldownElapses() {
        let offsets: [Double] = Array(repeating: 45, count: 12)
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }
        let dismissal = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!
        // 20 days later — well beyond the 14-day cooldown.
        let later = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 9))!

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: later,
            lastDismissal: dismissal
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.deltaMinutes, 45)
    }

    func testNeverRepitchesTheSameDeltaAfterDismissal() {
        let offsets: [Double] = Array(repeating: 45, count: 12)
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element) }
        let dismissal = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!
        let later = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 9))!

        // Cooldown elapsed, but the same +45 delta was already dismissed.
        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 8,
            currentReminderMinute: 0,
            now: later,
            lastDismissal: dismissal,
            lastDismissedDelta: 45
        )

        XCTAssertNil(suggestion)
    }

    func testHandlesTimeWrapWhenShiftCrossesMidnight() {
        // Reminder at 23:50, consistently ~30 minutes late -> wraps past midnight.
        let offsets: [Double] = Array(repeating: 30, count: 10)
        let logs = offsets.enumerated().map { log(dayOffset: $0.offset, offsetMinutes: $0.element, reminderHour: 23) }

        let suggestion = analyzer.suggestion(
            logs: logs,
            currentReminderHour: 23,
            currentReminderMinute: 50,
            now: now(20),
            lastDismissal: nil
        )

        XCTAssertEqual(suggestion?.deltaMinutes, 30)
        XCTAssertEqual(suggestion?.hour, 0)
        XCTAssertEqual(suggestion?.minute, 20)
    }
}

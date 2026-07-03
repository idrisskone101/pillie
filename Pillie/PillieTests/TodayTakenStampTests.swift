//
//  TodayTakenStampTests.swift
//  PillieTests
//
//  The App Group "today taken" flag was a bare Bool the DeviceActivityMonitor
//  extension trusted blindly — yesterday's true silently cancelled today's
//  blocking whenever the app didn't run between midnight and Due Action Time.
//  The stamp pairs the flag with the day it was written so the extension can
//  reject stale state without the main app running.
//

import XCTest

@testable import Pillie

final class TodayTakenStampTests: XCTestCase {
    private let calendar = Calendar.current
    private let noon = Calendar.current.date(
        bySettingHour: 12, minute: 0, second: 0, of: Date()
    )!

    func testTakenWithTodaysStampCountsAsTakenToday() {
        let stamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: noon, calendar: calendar)
        )

        XCTAssertTrue(stamp.isTakenToday(now: noon, calendar: calendar))
    }

    func testYesterdaysStaleTakenFlagDoesNotCancelTodaysBlocking() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: noon)!
        let stamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: yesterday, calendar: calendar)
        )

        XCTAssertFalse(stamp.isTakenToday(now: noon, calendar: calendar))
    }

    func testNotTakenIsNeverTakenTodayEvenWithTodaysStamp() {
        let stamp = TodayTakenStamp(
            isTaken: false,
            epochDay: TodayTakenStamp.epochDay(for: noon, calendar: calendar)
        )

        XCTAssertFalse(stamp.isTakenToday(now: noon, calendar: calendar))
    }

    func testLegacyFlagWithoutStampIsTreatedAsStale() {
        // Pre-upgrade installs have the Bool but no day stamp. Fail toward
        // blocking: a shield the user can dismiss beats silently skipped
        // protection.
        let stamp = TodayTakenStamp(isTaken: true, epochDay: nil)

        XCTAssertFalse(stamp.isTakenToday(now: noon, calendar: calendar))
    }
}

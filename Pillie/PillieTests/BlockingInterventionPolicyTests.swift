//
//  BlockingInterventionPolicyTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class BlockingInterventionPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    func testCycleDay27BreakClearsBlockingWhenAppStayedClosed() throws {
        let cycleStart = date(2026, 7, 1)
        let day26 = try XCTUnwrap(calendar.date(byAdding: .day, value: 25, to: cycleStart))
        let day27 = try XCTUnwrap(calendar.date(byAdding: .day, value: 26, to: cycleStart))
        let schedule = BlockingScheduleMirror(
            anchorDate: cycleStart,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: Array(0..<26)
        )
        let staleHandledStamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: day26, calendar: calendar)
        )

        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: schedule,
                handledStamp: staleHandledStamp,
                now: day27,
                calendar: calendar
            ),
            .clearShields
        )
    }

    func testEntireBreakWeekClearsBlockingWithoutDailyAppLaunches() throws {
        let cycleStart = date(2026, 7, 1)
        let schedule = BlockingScheduleMirror(
            anchorDate: cycleStart,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: Array(0..<21)
        )
        let staleHandledStamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: cycleStart, calendar: calendar)
        )

        for offset in 21...27 {
            let breakDay = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: cycleStart))
            XCTAssertEqual(
                BlockingInterventionPolicy.decision(
                    schedule: schedule,
                    handledStamp: staleHandledStamp,
                    now: breakDay,
                    calendar: calendar
                ),
                .clearShields,
                "Cycle day \(offset + 1) must never apply shields."
            )
        }
    }

    func testNextActiveCycleDayBlocksAgainWithoutAppLaunch() throws {
        let cycleStart = date(2026, 7, 1)
        let nextCycleStart = try XCTUnwrap(calendar.date(byAdding: .day, value: 28, to: cycleStart))
        let schedule = BlockingScheduleMirror(
            anchorDate: cycleStart,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: Array(0..<21)
        )
        let staleHandledStamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: cycleStart, calendar: calendar)
        )

        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: schedule,
                handledStamp: staleHandledStamp,
                now: nextCycleStart,
                calendar: calendar
            ),
            .applyShields
        )
    }

    func testHandledActiveDayClearsBlocking() {
        let cycleStart = date(2026, 7, 1)
        let schedule = BlockingScheduleMirror(
            anchorDate: cycleStart,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: Array(0..<21)
        )
        let handledToday = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: cycleStart, calendar: calendar)
        )

        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: schedule,
                handledStamp: handledToday,
                now: cycleStart,
                calendar: calendar
            ),
            .clearShields
        )
    }

    func testMissingLegacySchedulePreservesFailTowardBlockingBehavior() {
        let today = date(2026, 7, 1)
        let staleHandledStamp = TodayTakenStamp(isTaken: true, epochDay: nil)

        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: nil,
                handledStamp: staleHandledStamp,
                now: today,
                calendar: calendar
            ),
            .applyShields
        )
    }

    func testEmptyCorruptSchedulePreservesFailTowardBlockingBehavior() {
        let today = date(2026, 7, 1)
        let emptySchedule = BlockingScheduleMirror(
            anchorDate: today,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: []
        )

        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: emptySchedule,
                handledStamp: TodayTakenStamp(isTaken: false, epochDay: nil),
                now: today,
                calendar: calendar
            ),
            .applyShields
        )
    }

    func testMirroredScheduleRoundTripsThroughExtensionCodec() throws {
        let cycleStart = date(2026, 7, 1)
        let day27 = try XCTUnwrap(calendar.date(byAdding: .day, value: 26, to: cycleStart))
        let original = BlockingScheduleMirror(
            anchorDate: cycleStart,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: Array(0..<26)
        )

        let decoded = try XCTUnwrap(BlockingScheduleMirror.decode(from: original.encodedData()))

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: decoded,
                handledStamp: TodayTakenStamp(isTaken: false, epochDay: nil),
                now: day27,
                calendar: calendar
            ),
            .clearShields
        )
    }

    func testAnchorMathStaysAlignedAfterTimezoneAndDSTOffsetChange() throws {
        var torontoCalendar = Calendar(identifier: .gregorian)
        torontoCalendar.timeZone = TimeZone(identifier: "America/Toronto")!
        var limaCalendar = Calendar(identifier: .gregorian)
        limaCalendar.timeZone = TimeZone(identifier: "America/Lima")!
        let anchor = try XCTUnwrap(torontoCalendar.date(from: DateComponents(
            calendar: torontoCalendar,
            timeZone: torontoCalendar.timeZone,
            year: 2026,
            month: 3,
            day: 15,
            hour: 0
        )))
        let target = try XCTUnwrap(limaCalendar.date(from: DateComponents(
            calendar: limaCalendar,
            timeZone: limaCalendar.timeZone,
            year: 2026,
            month: 3,
            day: 16,
            hour: 12
        )))
        let schedule = BlockingScheduleMirror(
            anchorDate: anchor,
            anchorCycleDayIndex: 0,
            cycleLength: 28,
            actionDayIndices: [2]
        )

        // In Lima, the Toronto-midnight anchor is March 14 at 23:00. Both the
        // mirror and PillPack therefore normalize it to March 14 before counting.
        XCTAssertTrue(schedule.requiresAction(on: target, calendar: limaCalendar))
    }

    func testAppAndMonitorPolicySourcesStayByteIdentical() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = projectDirectory
            .appendingPathComponent("Pillie/Shared/BlockingScheduleMirror.swift")
        let monitorSource = projectDirectory
            .appendingPathComponent("PillieDeviceActivityMonitor/BlockingScheduleMirror.swift")

        XCTAssertEqual(
            try Data(contentsOf: appSource),
            try Data(contentsOf: monitorSource),
            "The app and DeviceActivity extension must evaluate the same mirrored schedule."
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))!
    }
}

//
//  ActiveDayScheduleTests.swift
//  PillieTests
//
//  Value-type unit tests for the pack-rhythm snapshot Reverse Trial walks.
//

import XCTest

@testable import Pillie

final class ActiveDayScheduleTests: XCTestCase {

    // Bare SwiftData models can deallocate inside the hosted XCTest
    // invocation on the Xcode 27 beta. Keep the pack for the process.
    private static var retainedPacks: [PillPack] = []

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testEveryCalendarDayIsAlwaysActive() {
        let schedule = ActiveDaySchedule.everyCalendarDay
        XCTAssertTrue(schedule.isActiveDay(date(2026, 7, 1), calendar: calendar))
        XCTAssertTrue(schedule.isActiveDay(date(2026, 7, 22), calendar: calendar))
        XCTAssertEqual(schedule.cycleDayIndex(on: date(2026, 7, 22), calendar: calendar), 0)
    }

    func testTwentyOneSevenBreakAfterDayTwentyOne() {
        // Grant local day is cycle day index 20 (pack day 21).
        let schedule = ActiveDaySchedule(
            anchorDate: date(2026, 7, 1, 10, 0),
            anchorDayIndex: 20,
            activeDays: 21,
            cycleLength: 28
        )

        XCTAssertEqual(schedule.cycleDayIndex(on: date(2026, 7, 1, 10, 0), calendar: calendar), 20)
        XCTAssertTrue(schedule.isActiveDay(date(2026, 7, 1, 10, 0), calendar: calendar))

        XCTAssertEqual(schedule.cycleDayIndex(on: date(2026, 7, 2), calendar: calendar), 21)
        XCTAssertFalse(schedule.isActiveDay(date(2026, 7, 2), calendar: calendar))

        XCTAssertEqual(schedule.cycleDayIndex(on: date(2026, 7, 8), calendar: calendar), 27)
        XCTAssertFalse(schedule.isActiveDay(date(2026, 7, 8), calendar: calendar))

        XCTAssertEqual(schedule.cycleDayIndex(on: date(2026, 7, 9), calendar: calendar), 0)
        XCTAssertTrue(schedule.isActiveDay(date(2026, 7, 9), calendar: calendar))
    }

    func testNormalizationAndEmptySetFailsTowardCountingEveryIndex() {
        let zeroLength = ActiveDaySchedule(
            anchorDate: date(2026, 7, 1),
            anchorDayIndex: 3,
            activeDays: 2,
            cycleLength: 0
        )
        XCTAssertEqual(zeroLength.cycleLength, 1)
        XCTAssertEqual(zeroLength.hormoneActiveIndices, [0])
        XCTAssertEqual(zeroLength.anchorDayIndex, 0)

        let overActive = ActiveDaySchedule(
            anchorDate: date(2026, 7, 1),
            anchorDayIndex: 0,
            activeDays: 99,
            cycleLength: 28
        )
        XCTAssertEqual(overActive.hormoneActiveIndices, Set(0..<28))

        let negativeAnchor = ActiveDaySchedule(
            anchorDate: date(2026, 7, 1),
            anchorDayIndex: -1,
            activeDays: 21,
            cycleLength: 28
        )
        XCTAssertEqual(negativeAnchor.anchorDayIndex, 27)

        let empty = ActiveDaySchedule(
            anchorDate: date(2026, 7, 1),
            anchorDayIndex: 0,
            cycleLength: 7,
            hormoneActiveIndices: []
        )
        XCTAssertEqual(empty.hormoneActiveIndices, Set(0..<7))
        XCTAssertTrue(empty.isActiveDay(date(2026, 7, 1), calendar: calendar))
    }

    func testPackSnapshotMatchesResolvedCycleAnchor() {
        let start = date(2026, 7, 1, 10, 0)
        let pack = PillPack(
            packType: .twentyOneSeven,
            method: .pill,
            pillRegimen: .twentyOneSeven,
            startDate: start,
            cycleDayAnchorIndex: 20,
            packNumber: 1,
            isCurrent: true
        )
        Self.retainedPacks.append(pack)
        let schedule = ActiveDaySchedule(pack: pack, calendar: calendar)

        XCTAssertEqual(schedule.hormoneActiveIndices, Set(0..<21))
        XCTAssertEqual(schedule.cycleLength, 28)
        XCTAssertEqual(
            schedule.cycleDayIndex(on: start, calendar: calendar),
            pack.cycleDayIndex(on: start, calendar: calendar)
        )
        XCTAssertEqual(
            schedule.cycleDayIndex(on: date(2026, 7, 9), calendar: calendar),
            pack.cycleDayIndex(on: date(2026, 7, 9), calendar: calendar)
        )
        XCTAssertEqual(schedule.cycleDayIndex(on: start, calendar: calendar), 20)
        XCTAssertEqual(schedule.cycleDayIndex(on: date(2026, 7, 9), calendar: calendar), 0)
    }

    func testPatchRemoveDayIsHormoneActive() {
        let start = date(2026, 7, 1, 10, 0)
        let pack = PillPack(
            packType: .twentyOneSeven,
            method: .patch,
            startDate: start,
            cycleDayAnchorIndex: 21,
            packNumber: 1,
            isCurrent: true
        )
        Self.retainedPacks.append(pack)

        XCTAssertTrue(pack.isBreakDay(dayIndex: 21))
        XCTAssertEqual(
            DoseScheduleEngine.dueAction(on: start, pack: pack, calendar: calendar)?.isBreak,
            false
        )

        let schedule = ActiveDaySchedule(pack: pack, calendar: calendar)
        XCTAssertEqual(schedule.hormoneActiveIndices, Set(0..<22))
        XCTAssertTrue(schedule.isActiveDay(start, calendar: calendar))
        XCTAssertFalse(schedule.isActiveDay(date(2026, 7, 2), calendar: calendar))
        XCTAssertTrue(schedule.isActiveDay(date(2026, 7, 8), calendar: calendar))
    }

    func testMissingPackIsEveryCalendarDay() {
        let schedule = ActiveDaySchedule(pack: nil, calendar: calendar)
        XCTAssertEqual(schedule, .everyCalendarDay)
    }
}

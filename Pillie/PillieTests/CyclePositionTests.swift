//
//  CyclePositionTests.swift
//  PillieTests
//
//  Verifies the coarse cycle-position toggle that anchors the Routine Details day
//  (#77). The toggle is a quick "Just starting / Mid-cycle / Near the end" set that
//  drives the exact cycle day; the day is what the production model actually stores,
//  so the mapping must always land inside [1, cycleLength] and round-trip back to the
//  highlighted bucket on back navigation. Pure value type — no host crash.
//

import XCTest

@testable import Pillie

final class CyclePositionTests: XCTestCase {
    func testThereAreExactlyThreeCoarsePositionsWithDistinctTitles() {
        XCTAssertEqual(CyclePosition.allCases.count, 3)
        XCTAssertEqual(
            CyclePosition.allCases.map(\.title),
            ["Just starting", "Mid-cycle", "Near the end"]
        )
        XCTAssertEqual(Set(CyclePosition.allCases.map(\.title)).count, 3)
    }

    func testPackTrackActiveIndexMatchesStartMidEndOrder() {
        XCTAssertEqual(CyclePosition.justStarting.packTrackActiveIndex, 0)
        XCTAssertEqual(CyclePosition.midCycle.packTrackActiveIndex, 1)
        XCTAssertEqual(CyclePosition.nearEnd.packTrackActiveIndex, 2)
    }

    func testAnchorDaysForAStandardTwentyEightDayCycle() {
        XCTAssertEqual(CyclePosition.justStarting.cycleDay(in: 28), 1)
        XCTAssertEqual(CyclePosition.midCycle.cycleDay(in: 28), 14)
        XCTAssertEqual(CyclePosition.nearEnd.cycleDay(in: 28), 28)
    }

    func testAnchorDayNeverEscapesTheCycleBounds() {
        for length in [21, 24, 28, 91, 365] {
            for position in CyclePosition.allCases {
                let day = position.cycleDay(in: length)
                XCTAssertGreaterThanOrEqual(day, 1, "position \(position) under-ran for length \(length)")
                XCTAssertLessThanOrEqual(day, length, "position \(position) over-ran for length \(length)")
            }
        }
        // A degenerate length must not crash or produce day 0.
        XCTAssertEqual(CyclePosition.nearEnd.cycleDay(in: 0), 1)
    }

    func testPositionAndDayRoundTripAcrossRealCycleLengths() {
        // Restoring the toggle highlight from the stored day must recover the same
        // bucket the anchor came from, for every real pill/patch/ring cycle length.
        for length in [21, 24, 26, 28, 91, 365] {
            for position in CyclePosition.allCases {
                let day = position.cycleDay(in: length)
                XCTAssertEqual(
                    CyclePosition.position(forCycleDay: day, cycleLength: length),
                    position,
                    "round-trip failed for \(position) at length \(length)"
                )
            }
        }
    }

    func testReversePositionClampsOutOfRangeDays() {
        XCTAssertEqual(CyclePosition.position(forCycleDay: -5, cycleLength: 28), .justStarting)
        XCTAssertEqual(CyclePosition.position(forCycleDay: 999, cycleLength: 28), .nearEnd)
    }
}

//
//  CalendarDayPresentationTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class CalendarDayPresentationTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testFuturePillDayHidesVisualStatusButKeepsDimmedIndicator() throws {
        let snapshot = try snapshot(
            method: .pill,
            type: .pillActive,
            status: .upcoming
        )

        let presentation = CalendarDayPresentation.resolve(
            snapshot: snapshot,
            fallbackMethod: .pill,
            relation: .future
        )

        XCTAssertEqual(presentation.visualStatus, nil)
        XCTAssertFalse(presentation.showVisual)
        XCTAssertTrue(presentation.isActionDay)
        XCTAssertEqual(presentation.defaultIndicatorOpacity, 0.4)
    }

    func testPastPatchChangeUsesTakenMissedAndUpcomingSemanticStyles() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .taken),
                fallbackMethod: .pill,
                relation: .past
            ).patchStyle,
            .changedTaken
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .missed),
                fallbackMethod: .pill,
                relation: .past
            ).patchStyle,
            .changedMissed
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .upcoming),
                fallbackMethod: .pill,
                relation: .today
            ).patchStyle,
            .changedUpcoming
        )
    }

    func testFuturePatchStylesSeparateChangeAppliedAndOffWeekDays() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .upcoming),
                fallbackMethod: .pill,
                relation: .future
            ).patchStyle,
            .plannedChange
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchActive, status: .upcoming),
                fallbackMethod: .pill,
                relation: .future
            ).patchStyle,
            .plannedApplied
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchBreak, status: .breakDay),
                fallbackMethod: .pill,
                relation: .future
            ).patchStyle,
            .plannedOffWeek
        )
    }

    func testRingPresentationStylesMissedFreeAndFutureReinsertDays() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringInsert, status: .missed),
                fallbackMethod: .pill,
                relation: .past
            ).ringStyle,
            .missed
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringBreak, status: .breakDay),
                fallbackMethod: .pill,
                relation: .today
            ).ringStyle,
            .ringFree
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringReinsert, status: .upcoming),
                fallbackMethod: .pill,
                relation: .future
            ).ringStyle,
            .plannedReinserted
        )
    }

    func testMissingSnapshotFallsBackToCurrentMethodWithoutScheduleContext() {
        let presentation = CalendarDayPresentation.resolve(
            snapshot: nil,
            fallbackMethod: .ring,
            relation: .today
        )

        XCTAssertEqual(presentation.method, .ring)
        XCTAssertFalse(presentation.hasScheduleContext)
        XCTAssertEqual(presentation.ringStyle, .invalid)
        XCTAssertEqual(presentation.defaultIndicatorOpacity, 1)
    }

    /// Packs backing fabricated snapshots. The Xcode 27 beta hosted-XCTest runner
    /// aborts when a @MainActor/@Observable class (which includes @Model) deallocates
    /// mid-invocation (see xcode27-beta-mainactor-deinit-crash), so every pack is
    /// retained for the process lifetime instead of being scoped to the helper.
    private static var keepAlivePacks: [PillPack] = []

    private func snapshot(
        method: ContraceptiveMethod,
        type: PillDay.ActionType,
        status: PillDay.Status
    ) throws -> PillScheduleSnapshot {
        let now = InMemoryStoreFactory.fixedDate("2026-06-03")
        // A bare, un-inserted pack is enough for presentation resolution — no
        // PillStore or ModelContainer needed (both crash the beta host when they
        // deallocate inside the test invocation).
        let pack = PillPack(
            packType: .twentyOneSeven,
            method: method,
            pillRegimen: .twentyOneSeven,
            startDate: now,
            packNumber: 1,
            isCurrent: true
        )
        Self.keepAlivePacks.append(pack)

        let action = DoseScheduleAction(
            date: now,
            type: type,
            method: method,
            cycleDay: 1,
            cycleLength: pack.cycleLength
        )

        return PillScheduleSnapshot(
            date: now,
            pack: pack,
            cycleDayIndex: 0,
            dueAction: action,
            status: status,
            actionType: type
        )
    }
}

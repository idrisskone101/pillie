//
//  RoutineSetupDraftTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

final class RoutineSetupDraftTests: XCTestCase {
    func testCommonPillSetupIsReadyWithoutAdvancedEdits() {
        let draft = RoutineSetupDraft(method: .pill)

        XCTAssertEqual(
            draft.commit,
            RoutineSetupCommit(
                regimen: .twentyOneSeven,
                customActiveDays: nil,
                customBreakDays: nil,
                cycleDay: 1
            )
        )
    }

    func testCustomPillSetupPreservesCustomScheduleOutputs() {
        var draft = RoutineSetupDraft(method: .pill)

        draft.selectRegimen(.custom)
        draft.setCustomActiveDays(42)
        draft.setCustomBreakDays(3)
        draft.selectPosition(.midCycle)

        XCTAssertEqual(
            draft.commit,
            RoutineSetupCommit(
                regimen: .custom,
                customActiveDays: 42,
                customBreakDays: 3,
                cycleDay: 23
            )
        )
    }

    func testPatchSetupUsesItsFixedScheduleWithoutRegimenEdits() {
        var draft = RoutineSetupDraft(method: .patch)

        draft.selectPosition(.midCycle)

        XCTAssertEqual(draft.section, .fixedSchedule)
        XCTAssertEqual(draft.cycleLength, 28)
        XCTAssertEqual(draft.commit.cycleDay, 14)
        XCTAssertNil(draft.commit.customActiveDays)
        XCTAssertNil(draft.commit.customBreakDays)
    }

    func testRingSetupNeedsNoPillRegimenControls() {
        var draft = RoutineSetupDraft(method: .ring)

        draft.selectPosition(.nearEnd)

        XCTAssertEqual(draft.section, .fixedSchedule)
        XCTAssertTrue(draft.visibleCommonRegimens.isEmpty)
        XCTAssertEqual(draft.cycleLength, 28)
        XCTAssertEqual(draft.commit.cycleDay, 28)
    }

    func testSavedCustomValuesSeedWhenNavigatingBack() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let savedPack = PillPack(
            method: .pill,
            pillRegimen: .custom,
            customActiveDays: 30,
            customBreakDays: 5,
            startDate: today,
            cycleDayAnchorIndex: 11,
            packNumber: 1
        )

        let draft = RoutineSetupDraft(method: .pill, activePack: savedPack, today: today)

        XCTAssertEqual(
            draft.commit,
            RoutineSetupCommit(
                regimen: .custom,
                customActiveDays: 30,
                customBreakDays: 5,
                cycleDay: 12
            )
        )
        XCTAssertTrue(draft.requiresMoreOptions)
    }

    func testExactDayEditClampsToTheSelectedRegimenCycle() {
        var draft = RoutineSetupDraft(method: .pill)

        draft.selectRegimen(.twentyFourFour)
        draft.setExactCycleDay(99)

        XCTAssertEqual(draft.commit.cycleDay, 28)
    }
}

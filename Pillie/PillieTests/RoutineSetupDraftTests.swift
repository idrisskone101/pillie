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
                customRegimen: nil,
                cycleDay: 1
            )
        )
    }

    func testPatchSetupUsesItsFixedScheduleWithoutRegimenEdits() {
        var draft = RoutineSetupDraft(method: .patch)

        draft.selectPosition(.midCycle)

        XCTAssertEqual(draft.cycleLength, 28)
        XCTAssertEqual(draft.commit.cycleDay, 14)
        XCTAssertNil(draft.commit.customRegimen)
    }

    func testRingSetupNeedsNoPillRegimenControls() {
        var draft = RoutineSetupDraft(method: .ring)

        draft.selectPosition(.nearEnd)

        XCTAssertEqual(draft.cycleLength, 28)
        XCTAssertEqual(draft.commit.cycleDay, 28)
    }
}

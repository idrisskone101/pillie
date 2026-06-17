//
//  RoutineDetailsSectionTests.swift
//  PillieTests
//
//  Verifies the method-specific routing of the Routine Details screen (#77): a Pill
//  user picks a regimen, while Patch and Ring users see their fixed schedule instead
//  of an irrelevant pill-pack picker. Pure value type — no host crash.
//

import XCTest

@testable import Pillie

final class RoutineDetailsSectionTests: XCTestCase {
    func testPillShowsTheRegimenPicker() {
        XCTAssertEqual(RoutineDetailsSection(method: .pill), .pillRegimen)
    }

    func testPatchAndRingShowTheFixedSchedule() {
        XCTAssertEqual(RoutineDetailsSection(method: .patch), .fixedSchedule)
        XCTAssertEqual(RoutineDetailsSection(method: .ring), .fixedSchedule)
    }
}

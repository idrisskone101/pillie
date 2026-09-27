//
//  RoutineExactDayCardActionTests.swift
//  PillieTests
//
//  Verifies the exact-day disclosure toggle on the Routine Basics Details screen
//  (#77). Pure value type — no host crash.
//

import XCTest

@testable import Pillie

final class RoutineExactDayCardActionTests: XCTestCase {
    func testExactDayCardTapExpandsCollapsedEditor() {
        XCTAssertEqual(
            RoutineExactDayCardAction.resolve(isEditingExactDay: false),
            .expand
        )
    }
}

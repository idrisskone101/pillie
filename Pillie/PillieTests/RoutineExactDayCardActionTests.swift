//
//  RoutineExactDayCardActionTests.swift
//  PillieTests
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

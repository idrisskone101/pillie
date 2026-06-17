//
//  RoutineRegimenCatalogTests.swift
//  PillieTests
//
//  Verifies the common-first regimen grouping for Routine Basics Details (#77). The
//  screen surfaces three common regimens and tucks the rest behind "More options" to
//  cut the busyness of the legacy seven-card form — but the grouping must still cover
//  every production preset, so no existing user loses their pack type. Pure values.
//

import XCTest

@testable import Pillie

final class RoutineRegimenCatalogTests: XCTestCase {
    func testCommonRegimensAreTheThreeSurfacedUpFront() {
        XCTAssertEqual(
            RoutineRegimenCatalog.common,
            [.twentyOneSeven, .twentyFourFour, .threeSixtyFiveZero]
        )
    }

    func testCommonPlusMoreCoversEveryRegimenExactlyOnce() {
        let combined = RoutineRegimenCatalog.common + RoutineRegimenCatalog.more
        // The simplification must not drop any preset: every production pack type is
        // still reachable, just relocated behind the disclosure.
        XCTAssertEqual(Set(combined), Set(PillPack.PillRegimenPreset.allCases))
        XCTAssertEqual(combined.count, PillPack.PillRegimenPreset.allCases.count)
        XCTAssertTrue(
            Set(RoutineRegimenCatalog.common).isDisjoint(with: Set(RoutineRegimenCatalog.more)),
            "common and more must not overlap"
        )
    }

    func testFriendlyDisplayNamesForTheCommonRegimens() {
        XCTAssertEqual(PillPack.PillRegimenPreset.twentyOneSeven.routineDisplayName, "Standard")
        XCTAssertEqual(PillPack.PillRegimenPreset.threeSixtyFiveZero.routineDisplayName, "Continuous")
        XCTAssertEqual(PillPack.PillRegimenPreset.custom.routineDisplayName, "Custom")
        // Less common ratios keep their familiar label rather than inventing a name.
        XCTAssertEqual(PillPack.PillRegimenPreset.twentyFourFour.routineDisplayName, "24/4")
    }
}

//
//  RoutineRegimenCatalogTests.swift
//  PillieTests
//
//  The Routine Details picker surfaces a few common regimens and tucks the rest
//  behind "More options". The grouping must still reach every preset, so no user
//  loses their pack type.
//

import Foundation
import Testing

@testable import Pillie

struct RoutineRegimenCatalogTests {
    @Test func `Common plus more covers every regimen exactly once`() {
        let combined = RoutineRegimenCatalog.common + RoutineRegimenCatalog.more

        #expect(Set(combined) == Set(PillPack.PillRegimenPreset.allCases))
        #expect(combined.count == PillPack.PillRegimenPreset.allCases.count)
    }

    @Test func `Every preset has a display name that is not its stored identity`() {
        let english = Locale(identifier: "en")

        #expect(
            PillPack.PillRegimenPreset.allCases.map { $0.localizedRoutineDisplayName(locale: english) }
                == ["Standard", "21", "24/4", "26/2", "Continuous", "21/4", "Custom cycle"]
        )
    }
}

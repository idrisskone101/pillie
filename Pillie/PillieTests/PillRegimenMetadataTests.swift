//
//  PillRegimenMetadataTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PillRegimenMetadataTests {
    @Test func `Every preset has a display name that is not its stored identity`() {
        let english = Locale(identifier: "en")

        #expect(
            PillPack.PillRegimenPreset.allCases.map { $0.localizedRoutineDisplayName(locale: english) }
                == ["Standard", "21 only", "24/4", "26/2", "Every day", "21/4", "Custom cycle"]
        )
    }
}

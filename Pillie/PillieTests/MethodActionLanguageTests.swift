//
//  MethodActionLanguageTests.swift
//  PillieTests
//
//  Verifies the method-aware "Due Action Time" phrasing used across Routine Basics
//  and the plan-builder card (#77). Broad brand copy may say "pill time" before the
//  method is known, but after method selection a Patch or Ring user must never see
//  their routine described in pill terms. Pure value type — runs without a host crash.
//

import XCTest

@testable import Pillie

final class MethodActionLanguageTests: XCTestCase {
    func testPillPhrasingIsMethodSpecific() {
        let language = MethodActionLanguage(method: .pill)
        XCTAssertEqual(language.momentLabel, "pill time")
        XCTAssertEqual(language.actionPhrase, "take your pill")
        XCTAssertEqual(language.objectNoun, "your pill")
    }

    func testPatchPhrasingNeverUsesPillWording() {
        let language = MethodActionLanguage(method: .patch)
        XCTAssertEqual(language.momentLabel, "patch day")
        XCTAssertEqual(language.actionPhrase, "change your patch")
        XCTAssertEqual(language.objectNoun, "your patch")
        for line in [language.momentLabel, language.actionPhrase, language.objectNoun] {
            XCTAssertFalse(line.lowercased().contains("pill"), "Patch copy leaked pill wording: \(line)")
        }
    }

    func testRingPhrasingNeverUsesPillWording() {
        let language = MethodActionLanguage(method: .ring)
        XCTAssertEqual(language.momentLabel, "ring day")
        XCTAssertEqual(language.actionPhrase, "check your ring")
        XCTAssertEqual(language.objectNoun, "your ring")
        for line in [language.momentLabel, language.actionPhrase, language.objectNoun] {
            XCTAssertFalse(line.lowercased().contains("pill"), "Ring copy leaked pill wording: \(line)")
        }
    }

    func testEveryMethodHasDistinctNonEmptyPhrasing() {
        let moments = ContraceptiveMethod.allCases.map { MethodActionLanguage(method: $0).momentLabel }
        let actions = ContraceptiveMethod.allCases.map { MethodActionLanguage(method: $0).actionPhrase }
        // Distinct per method, so personalization is genuinely method-aware.
        XCTAssertEqual(Set(moments).count, ContraceptiveMethod.allCases.count)
        XCTAssertEqual(Set(actions).count, ContraceptiveMethod.allCases.count)
        for method in ContraceptiveMethod.allCases {
            let language = MethodActionLanguage(method: method)
            for line in [language.momentLabel, language.actionPhrase, language.objectNoun] {
                XCTAssertFalse(line.isEmpty)
                // Non-medical boundary: no clinical/effectiveness claims in routine copy.
                let lowered = line.lowercased()
                for banned in ["doctor", "prescri", "diagnos", "guarantee", "clinically", "fda"] {
                    XCTAssertFalse(lowered.contains(banned), "Found \"\(banned)\" in: \(line)")
                }
            }
        }
    }
}

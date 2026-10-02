//
//  TodayPillQuestionTemplateTests.swift
//  PillieTests
//

// Value types only, so the Xcode 27 beta @MainActor deinit crash cannot fire.

import XCTest

@testable import Pillie

final class TodayPillQuestionTemplateTests: XCTestCase {
    func testSplitsTheEnglishTemplateAroundTheChipKeepingTrailingPunctuation() {
        let parts = TodayPillQuestionTemplate.split("Have you taken pill %@ yet?")
        XCTAssertEqual(parts.prefix, "Have you taken pill")
        XCTAssertTrue(parts.prefixSpaced)
        XCTAssertEqual(parts.suffix, "yet?")
        XCTAssertTrue(parts.suffixSpaced)
    }

    func testSplitsTheSpanishTemplateKeepingTheQuestionMarkAttachedToTheChip() {
        let parts = TodayPillQuestionTemplate.split("¿Ya tomaste la píldora %@?")
        XCTAssertEqual(parts.prefix, "¿Ya tomaste la píldora")
        XCTAssertTrue(parts.prefixSpaced)
        XCTAssertEqual(parts.suffix, "?")
        XCTAssertFalse(parts.suffixSpaced)
    }

    func testSplitsTheArabicTemplateAroundTheChip() {
        let parts = TodayPillQuestionTemplate.split("هل أخذتِ الحبة %@ بعد؟")
        XCTAssertEqual(parts.prefix, "هل أخذتِ الحبة")
        XCTAssertTrue(parts.prefixSpaced)
        XCTAssertEqual(parts.suffix, "بعد؟")
        XCTAssertTrue(parts.suffixSpaced)
    }
}

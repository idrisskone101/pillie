//
//  TrialDeclineFeedbackContentTests.swift
//  PillieTests
//
//  Localized value-type UI contract for issue #243.
//

import XCTest

@testable import Pillie

final class TrialDeclineFeedbackContentTests: XCTestCase {
    func testContentResolvesForEveryShippedLocale() {
        let english = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "en"))
        let italian = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "it"))
        let german = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "de"))

        XCTAssertEqual(english.continueFree, "Continue free")
        XCTAssertEqual(english.skip, "Skip")
        XCTAssertEqual(italian.continueFree, "Continua gratis")
        XCTAssertEqual(italian.skip, "Salta")
        XCTAssertEqual(german.continueFree, "Kostenlos fortfahren")
        XCTAssertEqual(german.skip, "Überspringen")
        XCTAssertFalse(english.title.isEmpty)
        XCTAssertFalse(english.prompt.isEmpty)
        XCTAssertFalse(english.optionalNote.isEmpty)
        XCTAssertFalse(english.thankYou.isEmpty)
    }
}

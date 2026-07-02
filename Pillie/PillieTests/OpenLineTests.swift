//
//  OpenLineTests.swift
//  PillieTests
//
//  Pins the Open Line's externally observable contract (PRD #152 / #153): the
//  always-available Settings support channel opens a `mailto:` composer to Pillie
//  support with an intent-specific subject. The subject strings are mechanical and
//  stable — inbox filters depend on them — while the warm row labels live in the UI
//  and may change freely. Modeled on `FeedbackEscapeHatchTests`, which pins the
//  distinct, prompt-driven negative-path contract this must never touch.
//

import XCTest

@testable import Pillie

final class OpenLineTests: XCTestCase {

    func testRecipientIsPillieSupportAddress() {
        XCTAssertEqual(OpenLine.recipient, "pillieapp@gmail.com")
    }

    func testSuggestionSubjectIsStableInboxFilterKey() {
        // Em dash, not hyphen: the exact string the developer's inbox filter matches.
        XCTAssertEqual(OpenLine.Intent.suggestion.subject, "Pillie — Suggestion")
    }

    func testSuggestionMailURLIsMailtoPreAddressedWithSubject() throws {
        let url = try XCTUnwrap(OpenLine.mailURL(for: .suggestion))
        XCTAssertEqual(url.scheme, "mailto")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        // The recipient rides the path, not a query item.
        XCTAssertEqual(components.path, "pillieapp@gmail.com")
        XCTAssertEqual(
            components.queryItems,
            [URLQueryItem(name: "subject", value: "Pillie — Suggestion")]
        )
    }

    func testSuggestionMailURLEncodesSubjectSpacesAndEmDash() throws {
        // Whole-URL shape: a tappable, pre-filled mailto the OS can route to Mail.
        let url = try XCTUnwrap(OpenLine.mailURL(for: .suggestion))
        XCTAssertEqual(
            url.absoluteString,
            "mailto:pillieapp@gmail.com?subject=Pillie%20%E2%80%94%20Suggestion"
        )
    }

    func testSuggestionMailURLCarriesNoBody() throws {
        // The suggestion intent seeds no body at all: the user writes freely and
        // nothing the Open Line builds can carry message content anywhere.
        let url = try XCTUnwrap(OpenLine.mailURL(for: .suggestion))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let names = (components.queryItems ?? []).map(\.name)
        XCTAssertFalse(names.contains("body"))
    }
}

//
//  FeedbackEscapeHatchTests.swift
//  PillieTests
//
//  Pins the negative-path Feedback Escape Hatch (PRD #132 / #134 / ADR 0005):
//  the Sentiment Gate's negative choice opens a native Mail composer pre-addressed
//  to `pillieapp@gmail.com` with a "Pillie feedback" subject. ADR 0005 fixes this
//  as `mailto:` only (Pillie has no backend), so the address + subject are the
//  whole contract — and the only part the user-typed body must never touch.
//

import XCTest

@testable import Pillie

final class FeedbackEscapeHatchTests: XCTestCase {

    func testRecipientIsPillieSupportAddress() {
        XCTAssertEqual(FeedbackEscapeHatch.recipient, "pillieapp@gmail.com")
    }

    func testSubjectIsPillieFeedback() {
        XCTAssertEqual(FeedbackEscapeHatch.subject, "Pillie feedback")
    }

    func testMailURLIsMailtoPreAddressedWithSubject() throws {
        let url = try XCTUnwrap(FeedbackEscapeHatch.mailURL)
        XCTAssertEqual(url.scheme, "mailto")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        // The recipient rides the path, not a query item.
        XCTAssertEqual(components.path, "pillieapp@gmail.com")
        XCTAssertEqual(
            components.queryItems,
            [URLQueryItem(name: "subject", value: "Pillie feedback")]
        )
    }

    func testMailURLEncodesSubjectSpace() throws {
        // Whole-URL shape: a tappable, pre-filled mailto the OS can route to Mail.
        let url = try XCTUnwrap(FeedbackEscapeHatch.mailURL)
        XCTAssertEqual(url.absoluteString, "mailto:pillieapp@gmail.com?subject=Pillie%20feedback")
    }

    func testMailURLCarriesNoBody() throws {
        // The user's typed feedback is private: the escape hatch never seeds or
        // captures a body, so nothing it builds can leak feedback text.
        let url = try XCTUnwrap(FeedbackEscapeHatch.mailURL)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let names = (components.queryItems ?? []).map(\.name)
        XCTAssertFalse(names.contains("body"))
    }
}

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

    /// Representative diagnostics: plain values a test can construct without any
    /// `Bundle`/`UIDevice` I/O, so the body contract stays deterministic. The
    /// live values are read at the call site, never here.
    private static let sampleDiagnostics = OpenLine.Diagnostics(
        appVersion: "2.0.1",
        build: "42",
        systemVersion: "26.2",
        deviceModel: "iPhone17,1"
    )

    func testRecipientIsPillieSupportAddress() {
        XCTAssertEqual(OpenLine.recipient, "pillieapp@gmail.com")
    }

    func testIssueReportSubjectIsStableInboxFilterKey() {
        // Em dash, not hyphen: the exact string the developer's inbox filter matches.
        let intent = OpenLine.Intent.issueReport(Self.sampleDiagnostics)
        XCTAssertEqual(intent.subject, "Pillie — Issue Report")
    }

    func testIssueReportBodyFooterCarriesInjectedDiagnostics() throws {
        // The footer is built from the injected plain values verbatim — no I/O,
        // one stacked line each, so the developer can reproduce at a glance.
        let body = try XCTUnwrap(OpenLine.Intent.issueReport(Self.sampleDiagnostics).body)
        XCTAssertTrue(body.contains("App: 2.0.1 (42)"), body)
        XCTAssertTrue(body.contains("iOS: 26.2"), body)
        XCTAssertTrue(body.contains("Device: iPhone17,1"), body)
    }

    func testIssueReportBodyOpensWithWarmInvitationAboveTheFooter() throws {
        // The "describe what happened above this line" register: the user writes
        // above the footer, which sits at the bottom as a diagnostics rule.
        let body = try XCTUnwrap(OpenLine.Intent.issueReport(Self.sampleDiagnostics).body)
        XCTAssertTrue(
            body.hasPrefix("Tell us what went wrong — the more detail, the better. Type above this line."),
            body
        )
    }

    func testIssueReportBodyIsTheFullContract() throws {
        // The whole body, pinned exactly: invitation, blank line, then the footer.
        let body = try XCTUnwrap(OpenLine.Intent.issueReport(Self.sampleDiagnostics).body)
        XCTAssertEqual(
            body,
            """
            Tell us what went wrong — the more detail, the better. Type above this line.

            ———
            App: 2.0.1 (42)
            iOS: 26.2
            Device: iPhone17,1
            """
        )
    }

    func testSuggestionSubjectIsStableInboxFilterKey() {
        // Em dash, not hyphen: the exact string the developer's inbox filter matches.
        XCTAssertEqual(OpenLine.Intent.suggestion.subject, "Pillie — Suggestion")
    }

    func testIssueReportMailURLIsMailtoPreAddressedWithSubjectAndBody() throws {
        let url = try XCTUnwrap(OpenLine.mailURL(for: .issueReport(Self.sampleDiagnostics)))
        XCTAssertEqual(url.scheme, "mailto")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        // The recipient rides the path, not a query item.
        XCTAssertEqual(components.path, "pillieapp@gmail.com")
        // The full contract: stable subject plus the seeded diagnostics body,
        // round-tripped through decoding so the whole string is pinned.
        XCTAssertEqual(
            components.queryItems,
            [
                URLQueryItem(name: "subject", value: "Pillie — Issue Report"),
                URLQueryItem(
                    name: "body",
                    value: """
                    Tell us what went wrong — the more detail, the better. Type above this line.

                    ———
                    App: 2.0.1 (42)
                    iOS: 26.2
                    Device: iPhone17,1
                    """
                )
            ]
        )
    }

    func testIssueReportMailURLIsPercentEncodedAndTappable() throws {
        // A single tappable mailto the OS can route: no raw spaces or newlines
        // survive into the URL string.
        let url = try XCTUnwrap(OpenLine.mailURL(for: .issueReport(Self.sampleDiagnostics)))
        XCTAssertFalse(url.absoluteString.contains(" "), url.absoluteString)
        XCTAssertFalse(url.absoluteString.contains("\n"), url.absoluteString)
    }

    func testIssueReportBodyNeverContainsRoutineVocabulary() throws {
        // The diagnostics footer is device/app info only. Routine data —
        // contraception method, cycle day, reminder times, streaks, blocking
        // configuration — must never ride the composer body. Given representative
        // inputs, none of that domain vocabulary appears.
        let body = try XCTUnwrap(OpenLine.Intent.issueReport(Self.sampleDiagnostics).body).lowercased()
        for term in ["method", "cycle", "reminder", "streak", "block", "patch", "ring"] {
            XCTAssertFalse(body.contains(term), "body leaked routine vocabulary: \(term)")
        }
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

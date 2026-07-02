//
//  OpenLineTelemetryTests.swift
//  PillieTests
//
//  Pins the Open Line's coarse funnel signal (PRD #152 / #153): one event per row
//  tap, named stably so funnel history survives copy changes, carrying nothing
//  beyond the standard envelope. iOS never reports whether an email was actually
//  sent, so the row tap is by design the only signal — and what the user types is
//  private and must never appear in telemetry.
//

import XCTest

@testable import Pillie

@MainActor
final class OpenLineTelemetryTests: XCTestCase {

    func testSuggestionRowTapEventUsesApprovedName() {
        XCTAssertEqual(
            AnalyticsEvent.openLineSuggestionTapped.rawValue,
            "open_line_suggestion_tapped"
        )
    }

    func testIssueReportRowTapEventUsesApprovedName() {
        // The second and final Open Line event — the "exactly two, nothing more"
        // budget. Stable name so funnel history survives copy changes.
        XCTAssertEqual(
            AnalyticsEvent.openLineIssueReportTapped.rawValue,
            "open_line_issue_report_tapped"
        )
    }

    func testOpenLineTapPayloadIsStandardEnvelopeOnly() {
        // Source and the coarse plan flag — no setting category, no message
        // content, no intent detail beyond the event name itself.
        let properties = AnalyticsPayload(
            source: .settings,
            isPlus: false
        ).properties

        XCTAssertEqual(properties, [
            "source": .string("settings"),
            "is_plus": .bool(false)
        ])
    }
}

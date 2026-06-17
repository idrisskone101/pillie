//
//  ProtectionPlanRoutineSummaryTests.swift
//  PillieTests
//
//  Verifies the live "Your plan so far" card model that threads Routine Method →
//  Details → Reminder Time into one building plan (#77). The headline is method-aware
//  and progressive; the receipt rows appear in commit order. Pure value type.
//

import XCTest

@testable import Pillie

final class ProtectionPlanRoutineSummaryTests: XCTestCase {
    func testEmptySummaryShowsAnInvitationAndNoRows() {
        let summary = ProtectionPlanRoutineSummary()
        XCTAssertTrue(summary.rows.isEmpty)
        XCTAssertEqual(summary.headline, "Let's build your protection plan.")
    }

    func testMethodOnlyHeadlineIsForwardLookingAndMethodAware() {
        let summary = ProtectionPlanRoutineSummary(method: .pill)
        XCTAssertEqual(summary.headline, "Pillie will protect your pill.")
        XCTAssertEqual(summary.rows.map(\.label), ["Method"])
        XCTAssertEqual(summary.rows.first?.value, ContraceptiveMethod.pill.title)
    }

    func testCompleteSummaryReadsAsAProtectedPlanWithOrderedRows() {
        let summary = ProtectionPlanRoutineSummary(
            method: .pill,
            scheduleSummary: "Standard · 21 active, 7 break",
            cycleDay: 14,
            reminderTimeText: "9:30 AM"
        )
        XCTAssertEqual(summary.headline, "Pillie protects your pill at 9:30 AM.")
        // Rows fill in the order the user commits them across the three screens.
        XCTAssertEqual(summary.rows.map(\.label), ["Method", "Schedule", "Cycle day", "Reminder"])
        XCTAssertEqual(summary.rows.map(\.value), [
            ContraceptiveMethod.pill.title,
            "Standard · 21 active, 7 break",
            "Day 14",
            "9:30 AM",
        ])
    }

    func testHeadlineStaysMethodAwareForPatchAndRing() {
        // The brand name "Pillie" legitimately contains "pill", so the real contract
        // is that the pill-specific noun never leaks into a patch/ring headline.
        let patch = ProtectionPlanRoutineSummary(method: .patch, reminderTimeText: "8:00 AM")
        XCTAssertEqual(patch.headline, "Pillie protects your patch at 8:00 AM.")
        XCTAssertTrue(patch.headline.contains("your patch"))
        XCTAssertFalse(patch.headline.contains("your pill"))

        let ring = ProtectionPlanRoutineSummary(method: .ring)
        XCTAssertEqual(ring.headline, "Pillie will protect your ring.")
        XCTAssertTrue(ring.headline.contains("your ring"))
        XCTAssertFalse(ring.headline.contains("your pill"))
    }

    func testClockTextFormatsTwelveHourPickerSelections() {
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 9, minute: 30, isPM: false), "9:30 AM")
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 12, minute: 0, isPM: true), "12:00 PM")
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 1, minute: 5, isPM: false), "1:05 AM")
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 8, minute: 0, isPM: true), "8:00 PM")
    }

    func testHeadlineMakesNoMedicalOrFakeClaims() {
        let summary = ProtectionPlanRoutineSummary(
            method: .pill,
            scheduleSummary: "Standard · 21 active, 7 break",
            cycleDay: 1,
            reminderTimeText: "9:30 AM"
        )
        let lowered = summary.headline.lowercased()
        for banned in ["doctor", "prescri", "diagnos", "guarantee", "clinically", "fda", "%"] {
            XCTAssertFalse(lowered.contains(banned), "Headline made a banned claim: \(summary.headline)")
        }
    }
}

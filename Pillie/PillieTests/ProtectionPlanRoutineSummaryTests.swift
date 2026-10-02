//
//  ProtectionPlanRoutineSummaryTests.swift
//  PillieTests
//
//  Verifies the live "Your plan so far" card model that threads Routine Method →
//  Details → Reminder Time into one building plan (#77). The headline turns from an
//  invitation into the plan title once a method is chosen; the receipt rows appear
//  in commit order. Pure value type.
//

import XCTest

@testable import Pillie

final class ProtectionPlanRoutineSummaryTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func testEmptySummaryShowsAnInvitationAndNoRows() {
        let summary = ProtectionPlanRoutineSummary(locale: english)
        XCTAssertTrue(summary.rows.isEmpty)
        XCTAssertEqual(summary.headline, catalog("onboarding.plan.subtitle"))
        XCTAssertEqual(summary.accessibilityHeadings, [catalog("onboarding.plan.title"), catalog("onboarding.plan.subtitle")])
    }

    func testMethodOnlySummaryHeadsWithThePlanTitleAndOneMethodRow() {
        let summary = ProtectionPlanRoutineSummary(method: .pill, locale: english)
        XCTAssertEqual(summary.headline, catalog("onboarding.plan.title"))
        XCTAssertEqual(summary.accessibilityHeadings, [catalog("onboarding.plan.title")])
        XCTAssertEqual(summary.rows.map(\.label), [catalog("onboarding.plan.method")])
        XCTAssertEqual(summary.rows.first?.value, catalog("global.method.pill"))
    }

    func testCompleteSummaryListsRowsInCommitOrder() {
        let summary = ProtectionPlanRoutineSummary(
            method: .pill,
            scheduleSummary: "Standard · 21 active, 7 break",
            cycleDay: 14,
            reminderTimeText: "9:30 AM",
            locale: english
        )
        XCTAssertEqual(summary.headline, catalog("onboarding.plan.title"))
        XCTAssertEqual(summary.rows.map(\.label), [
            catalog("onboarding.plan.method"),
            catalog("onboarding.plan.schedule"),
            catalog("onboarding.plan.current_cycle"),
            catalog("onboarding.demo.step.reminder"),
        ])
        XCTAssertEqual(summary.rows.map(\.value), [
            catalog("global.method.pill"),
            "Standard · 21 active, 7 break",
            "Day 14",
            "9:30 AM",
        ])
    }

    func testHeadlineIsThePlanTitleForEveryChosenMethod() {
        for method in ContraceptiveMethod.allCases {
            let summary = ProtectionPlanRoutineSummary(method: method, reminderTimeText: "8:00 AM", locale: english)
            XCTAssertEqual(summary.headline, catalog("onboarding.plan.title"), "\(method)")
        }
    }

    func testClockTextFormatsTwelveHourPickerSelections() {
        // iOS puts a narrow no-break space (U+202F) between the time and AM/PM.
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 9, minute: 30, isPM: false, locale: english), "9:30\u{202F}AM")
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 12, minute: 0, isPM: true, locale: english), "12:00\u{202F}PM")
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 1, minute: 5, isPM: false, locale: english), "1:05\u{202F}AM")
        XCTAssertEqual(ProtectionPlanRoutineSummary.clockText(hour12: 8, minute: 0, isPM: true, locale: english), "8:00\u{202F}PM")
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

    /// Copy passes rewrite the English, so assert the key each field reads. A key
    /// missing from the catalog resolves to itself, which this rejects.
    private func catalog(_ key: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let value = PillieLocalization.string(key, locale: english)
        XCTAssertNotEqual(value, key, "Missing catalog key \(key)", file: file, line: line)
        return value
    }
}

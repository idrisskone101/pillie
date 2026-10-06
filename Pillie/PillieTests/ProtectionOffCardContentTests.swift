//
//  ProtectionOffCardContentTests.swift
//  PillieTests
//
//  Value-type unit tests for the Protection Off State Home card (issue #167 /
//  ADR 0007 / CONTEXT.md "Protection Off State"): shown only to the
//  blocker-configured cohort without Plus Access, persistent until access
//  returns, and never letting the user believe blocking is active. An expired
//  hard-paywall trial shows the reminders-off variant instead (ENG-167).
//  Mirrors BlockingStatusPresentation's value-type style.
//

import XCTest

@testable import Pillie

final class ProtectionOffCardContentTests: XCTestCase {

    // MARK: - Tracer bullet: expired access + saved blocker config shows the card

    func testNoAccessWithSavedBlockerConfigShowsCard() {
        let content = ProtectionOffCardContent.make(
            hasPlusAccess: false,
            blockerConfigSaved: true
        )

        XCTAssertEqual(content?.kind, .blockingStopped)
        XCTAssertEqual(content?.title, "App blocking is off")
        XCTAssertEqual(
            content?.detail,
            "Your Plus access ended, so your apps aren’t paused. Your setup is saved. Turn Plus back on and it picks up where you left off."
        )
        XCTAssertEqual(content?.ctaTitle, "Turn Plus back on")
    }

    // MARK: - Stopped reminders outrank blocking (ENG-167)

    func testStoppedRemindersShowRemindersCardForBothCohorts() {
        for blockerConfigSaved in [true, false] {
            let content = ProtectionOffCardContent.make(
                hasPlusAccess: false,
                blockerConfigSaved: blockerConfigSaved,
                remindersStopped: true
            )

            XCTAssertEqual(content?.kind, .remindersStopped)
            XCTAssertEqual(content?.title, "Your daily reminders are off")
            XCTAssertEqual(
                content?.detail,
                "Your trial ended, so Pillie isn’t sending reminders. Pick a plan to turn them back on. Your setup is saved."
            )
            XCTAssertEqual(content?.ctaTitle, "Turn Plus back on")
        }
    }

    // MARK: - The card disappears the moment access returns

    func testPlusAccessHidesCard() {
        // Re-purchase (or a fresh grant) restores protection — the card's only
        // job is done, with no dismissal state to reset.
        XCTAssertNil(ProtectionOffCardContent.make(
            hasPlusAccess: true,
            blockerConfigSaved: true
        ))
    }

    // MARK: - Never-configured cohort never sees it

    func testNoSavedBlockerConfigHidesCard() {
        // A user who never configured the blocker lost nothing when the trial
        // ended — they get the Trial-End Paywall's gain framing, not this card
        // (BlockingStatusCard owns the reminder-only cohort).
        XCTAssertNil(ProtectionOffCardContent.make(
            hasPlusAccess: false,
            blockerConfigSaved: false
        ))
    }
}

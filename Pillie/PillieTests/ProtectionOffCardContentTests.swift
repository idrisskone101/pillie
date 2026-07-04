//
//  ProtectionOffCardContentTests.swift
//  PillieTests
//
//  Value-type unit tests for the Protection Off State Home card (issue #167 /
//  ADR 0007 / CONTEXT.md "Protection Off State"): shown only to the
//  blocker-configured cohort without Plus Access, persistent until access
//  returns, and never letting the user believe blocking is active. Mirrors
//  BlockingStatusPresentation's value-type style.
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

        XCTAssertEqual(content?.title, "App blocking is off")
        XCTAssertEqual(
            content?.detail,
            "Your Plus access ended, so apps aren't being blocked. Your blocker setup is saved — turn Plus back on to pick up right where you left off."
        )
        XCTAssertEqual(content?.ctaTitle, "Turn protection back on")
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

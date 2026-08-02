//
//  TrialGrantedMomentContentTests.swift
//  PillieTests
//
//  Issue #164: the Trial Granted Moment (faithful Claude Design "Mapped, warmer"
//  variant 2a). A non-purchase announcement that the Reverse Trial has started.
//  These value-type tests pin the App Review pre-trial disclosures (duration,
//  what turns off, post-trial price) and the no-purchase-UI boundary: one
//  continue action, nothing to buy, no decline path.
//

import XCTest

@testable import Pillie

final class TrialGrantedMomentContentTests: XCTestCase {
    private let content = TrialGrantedMomentContent.default

    // MARK: - App Review pre-trial disclosures (one plain line)

    func testDisclosureLineCarriesDurationWhatTurnsOffAndPostTrialPrice() {
        XCTAssertEqual(
            content.disclosure,
            "Your free trial lasts 14 days. App blocking turns off when it ends, while reminders stay free."
        )
    }

    func testDisclosureIsPartOfTheVisibleCopy() {
        XCTAssertTrue(content.visibleCopy.contains(content.disclosure))
    }

    // MARK: - Single continue action, nothing to buy

    func testTheOnlyActionIsTheSingleContinueCTA() {
        XCTAssertEqual(content.primaryCTA, "Continue to app blocking")
    }

    func testCopyOffersNothingToBuyAndNoDeclinePath() {
        // No purchase UI and no decline path: the screen never asks the user to
        // buy, pick a plan, restore, or opt out (there is nothing to decline).
        let copy = content.visibleCopy.joined(separator: " ").lowercased()
        for purchaseWord in ["buy", "subscribe", "purchase", "restore", "$4.99", "/month", "per month", "no thanks", "skip", "maybe later"] {
            XCTAssertFalse(copy.contains(purchaseWord), "Trial Granted copy must not contain \"\(purchaseWord)\".")
        }
    }

    // MARK: - Faithful 2a copy

    func testHeadlineAndBadgeMatchTheMappedWarmerDesign() {
        XCTAssertEqual(content.badge, "14 days free · no card")
        XCTAssertEqual(content.title, "Your next two weeks,")
        XCTAssertEqual(content.titleAccent, "on us.")
        XCTAssertEqual(content.subtitle, "A full trial of Pillie Plus starts now — here's how it goes.")
    }

    func testTimelineMapsTodayHeadsUpAndDayFourteenChoice() {
        XCTAssertEqual(content.today.label, "Today")
        XCTAssertEqual(content.today.title, "Everything unlocks")
        XCTAssertEqual(content.today.perks.map(\.title), [
            "App blocking", "Shake to confirm", "Smart Reminders", "Custom messages",
        ])

        XCTAssertEqual(content.laterDays.map(\.label), ["Day 12", "Day 14"])
        XCTAssertEqual(content.laterDays.map(\.title), ["A gentle heads-up", "You choose"])
        XCTAssertEqual(
            content.laterDays.map(\.detail),
            [
                "We'll remind you before your trial ends. No surprises.",
                "Keep reminders free, or choose whether to continue with Plus.",
            ]
        )
    }

    func testGermanTrialGrantedMomentUsesCompleteIdiomaticCopy() {
        let german = TrialGrantedMomentContent.localized(locale: Locale(identifier: "de_DE"))

        XCTAssertEqual(german.badge, "14 Tage gratis · keine Karte")
        XCTAssertEqual(german.title, "Deine nächsten zwei Wochen")
        XCTAssertEqual(german.titleAccent, "gehen auf uns.")
        XCTAssertEqual(german.laterDays.map(\.label), ["Tag 12", "Tag 14"])
        XCTAssertEqual(german.laterDays.map(\.title), ["Eine kurze Erinnerung", "Du entscheidest"])
        XCTAssertEqual(
            german.laterDays.map(\.detail),
            [
                "Bevor deine Testphase endet, geben wir dir rechtzeitig Bescheid. Ohne Überraschungen.",
                "Erinnerungen bleiben kostenlos. Plus behältst du nur, wenn du möchtest.",
            ]
        )
        XCTAssertEqual(german.primaryCTA, "Weiter zur App-Pause")
    }

    // MARK: - Truthful copy (ADR 0002 rules stand)

    func testCopyNeverPromisesActiveBlockingBeforeSetup() {
        // Blocking is unlocked by the trial but not yet configured; the copy must
        // not claim protection is already running (that claim belongs to the
        // Protection Plan Ready screen after a valid blocker save).
        let copy = content.visibleCopy.joined(separator: " ").lowercased()
        for claim in ["you're protected", "blocking is on", "blocking is active", "now blocking"] {
            XCTAssertFalse(copy.contains(claim), "Trial Granted copy must not claim \"\(claim)\".")
        }
    }
}

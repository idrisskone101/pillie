//
//  UpdateTrialAnnouncementContentTests.swift
//  PillieTests
//
//  Issue #165: the one-time announcement sheet telling an existing onboarded
//  free user that Plus is now free for them for 14 days. These value-type tests
//  pin the App Review pre-trial disclosures (identical to the onboarding Trial
//  Granted Moment so the two can never drift), the primary action into blocker
//  setup, the dismiss path, and the no-purchase-UI boundary.
//

import XCTest

@testable import Pillie

final class UpdateTrialAnnouncementContentTests: XCTestCase {
    private let content = UpdateTrialAnnouncementContent.default

    // MARK: - Pre-trial disclosures (same duty as the Trial Granted Moment)

    func testDisclosureIsIdenticalToTheTrialGrantedMoment() {
        // One source of truth for duration / what turns off / post-trial price:
        // the sheet carries exactly the Trial Granted Moment's disclosure line.
        XCTAssertEqual(content.disclosure, TrialGrantedMomentContent.default.disclosure)
    }

    func testDisclosureIsPartOfTheVisibleCopy() {
        XCTAssertTrue(content.visibleCopy.contains(content.disclosure))
    }

    // MARK: - Actions: blocker setup + dismiss

    func testPrimaryActionLeadsIntoBlockerSetup() {
        XCTAssertEqual(content.primaryCTA, "Set up app blocking")
    }

    func testSheetIsDismissible() {
        // Unlike the onboarding Trial Granted Moment (no decline path), the
        // announcement interrupts an existing user's session — it must offer a
        // way out that promises nothing.
        XCTAssertEqual(content.dismissCTA, "Not now")
    }

    // MARK: - Announcement copy

    func testHeadlineAnnouncesPlusIsNowFreeForFourteenDays() {
        XCTAssertEqual(content.badge, "14 days free · no card")
        XCTAssertEqual(content.title, "Pillie Plus is now")
        XCTAssertEqual(content.titleAccent, "free for you.")
        XCTAssertEqual(
            content.subtitle,
            "This update starts your full 14-day Plus trial — everything unlocks now."
        )
        XCTAssertEqual(content.perks.map(\.title), [
            "App blocking", "Shake to confirm", "Smart Reminders", "Custom messages",
        ])
    }

    // MARK: - No purchase UI (the sheet announces, it never sells)

    func testCopyOffersNothingToBuy() {
        let copy = content.visibleCopy.joined(separator: " ").lowercased()
        for purchaseWord in ["buy", "subscribe", "purchase", "restore", "$4.99", "/month", "per month"] {
            XCTAssertFalse(copy.contains(purchaseWord), "Announcement copy must not contain \"\(purchaseWord)\".")
        }
    }

    // MARK: - Truthful copy (ADR 0002 rules stand)

    func testCopyNeverPromisesActiveBlockingBeforeSetup() {
        // Blocking is unlocked by the grant but not yet configured — that is the
        // whole point of the primary CTA. The copy must not claim protection is
        // already running.
        let copy = content.visibleCopy.joined(separator: " ").lowercased()
        for claim in ["you're protected", "blocking is on", "blocking is active", "now blocking"] {
            XCTAssertFalse(copy.contains(claim), "Announcement copy must not claim \"\(claim)\".")
        }
    }
}

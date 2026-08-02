//
//  BlockingStatusPresentationTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

final class BlockingStatusPresentationTests: XCTestCase {
    func testSettingsToggleStatusFollowsEnabledPreference() {
        let english = Locale(identifier: "en")

        XCTAssertEqual(
            SettingsPresentation.blockingToggleStatus(isEnabled: true, locale: english),
            "On"
        )
        XCTAssertEqual(
            SettingsPresentation.blockingToggleStatus(isEnabled: false, locale: english),
            "Off"
        )
    }

    // MARK: - Mapping from completion state

    func testActivatedUserShowsActivePresentation() {
        XCTAssertEqual(
            BlockingStatusPresentation.make(outcome: .protectionPlanActivated, isEntitled: true),
            .active
        )
    }

    func testReminderOnlyEntitledUserShowsIncompleteEntitledPresentation() {
        XCTAssertEqual(
            BlockingStatusPresentation.make(outcome: .reminderOnly, isEntitled: true),
            .incompleteEntitled
        )
    }

    func testReminderOnlyFreeUserShowsIncompleteFreePresentation() {
        XCTAssertEqual(
            BlockingStatusPresentation.make(outcome: .reminderOnly, isEntitled: false),
            .incompleteFree
        )
    }

    // MARK: - When to surface the enable-blocking-later prompt

    func testActivatedUserDoesNotSeeEnableBlockingPrompt() {
        XCTAssertFalse(BlockingStatusPresentation.active.showsEnableBlockingPrompt)
    }

    func testReminderOnlyUsersSeeEnableBlockingPrompt() {
        XCTAssertTrue(BlockingStatusPresentation.incompleteEntitled.showsEnableBlockingPrompt)
        XCTAssertTrue(BlockingStatusPresentation.incompleteFree.showsEnableBlockingPrompt)
    }

    // MARK: - Card content

    func testActivatedPresentationHasNoCardContent() {
        XCTAssertNil(BlockingStatusCardContent.make(for: .active))
    }

    func testEntitledIncompleteCardLabelsBlockingIncompleteAndOffersSetup() throws {
        let card = try XCTUnwrap(BlockingStatusCardContent.make(for: .incompleteEntitled))

        // AC3: clearly labels blocking as incomplete / not active.
        let copy = card.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertTrue(
            copy.contains("isn't on") || copy.contains("not on")
                || copy.contains("isn't set up") || copy.contains("incomplete")
        )
        // AC4: a clear path to enable blocking later.
        XCTAssertTrue(card.ctaTitle.lowercased().contains("set up"))
        // Entitled users go straight to Screen Time setup, not the paywall.
        XCTAssertFalse(card.isLocked)
        // Must not falsely claim blocking is active/on.
        XCTAssertFalse(copy.contains("active"))
        XCTAssertFalse(copy.contains("blocking is on"))
    }

    func testFreeIncompleteCardLabelsBlockingOffAndOffersUpgrade() throws {
        let card = try XCTUnwrap(BlockingStatusCardContent.make(for: .incompleteFree))

        let copy = card.visibleCopy.joined(separator: " ").lowercased()
        // AC3: blocking is clearly not on.
        XCTAssertTrue(copy.contains("isn't on") || copy.contains("not on") || copy.contains("isn't set up"))
        // AC4 (free variant): the path is unlocking via Plus.
        XCTAssertTrue(copy.contains("plus") || copy.contains("unlock"))
        XCTAssertTrue(card.isLocked)
        XCTAssertFalse(copy.contains("active"))
    }

    func testReminderOnlyCardsReassureRemindersStillWork() throws {
        // The completion/home state should reassure the user reminders are active even
        // though blocking is incomplete (truthful free-path framing).
        for presentation in [BlockingStatusPresentation.incompleteEntitled, .incompleteFree] {
            let card = try XCTUnwrap(BlockingStatusCardContent.make(for: presentation))
            let copy = card.visibleCopy.joined(separator: " ").lowercased()
            XCTAssertTrue(copy.contains("reminder"), "\(presentation) card should reassure reminders are active.")
        }
    }
}

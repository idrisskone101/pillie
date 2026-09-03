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
        let english = Locale(identifier: "en_US")
        let card = try XCTUnwrap(
            BlockingStatusCardContent.make(for: .incompleteEntitled, locale: english)
        )

        XCTAssertEqual(
            card.title,
            PillieLocalization.string("today.protection.setup.title", locale: english)
        )
        XCTAssertEqual(
            card.ctaTitle,
            PillieLocalization.string("today.protection.setup.cta", locale: english)
        )
        XCTAssertFalse(card.isLocked)
        XCTAssertFalse(card.visibleCopy.joined(separator: " ").lowercased().contains("blocking is on"))
    }

    func testFreeIncompleteCardLabelsBlockingOffAndOffersUpgrade() throws {
        let english = Locale(identifier: "en_US")
        let card = try XCTUnwrap(
            BlockingStatusCardContent.make(for: .incompleteFree, locale: english)
        )

        XCTAssertEqual(
            card.title,
            PillieLocalization.string("today.protection.inactive", locale: english)
        )
        XCTAssertEqual(
            card.ctaTitle,
            PillieLocalization.string("today.protection.off.cta", locale: english)
        )
        XCTAssertTrue(card.detail.lowercased().contains("plus"))
        XCTAssertTrue(card.isLocked)
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

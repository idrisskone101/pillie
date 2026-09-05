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
    private let english = Locale(identifier: "en_US")
    private var content: TrialGrantedMomentContent {
        TrialGrantedMomentContent.localized(locale: english)
    }

    private func commerce(_ key: String, locale: Locale? = nil) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale ?? english)
    }

    // MARK: - App Review pre-trial disclosures (one plain line)

    func testDisclosureLineCarriesDurationWhatTurnsOffAndPostTrialPrice() {
        XCTAssertEqual(content.disclosure, commerce("trial.granted.disclosure"))
    }

    func testDisclosureIsPartOfTheVisibleCopy() {
        XCTAssertTrue(content.visibleCopy.contains(content.disclosure))
    }

    func testHardPaywallDayFourteenRequiresAPaidPlanToContinue() {
        let hardPaywallContent = TrialGrantedMomentContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        XCTAssertEqual(
            hardPaywallContent.laterDays.last?.detail,
            commerce("trial.granted.choice.detail.hard_paywall")
        )
        XCTAssertEqual(
            hardPaywallContent.disclosure,
            commerce("trial.granted.disclosure.hard_paywall")
        )
    }

    // MARK: - Single continue action, nothing to buy

    func testTheOnlyActionIsTheSingleContinueCTA() {
        XCTAssertEqual(content.primaryCTA, commerce("trial.granted.cta"))
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
        XCTAssertEqual(content.badge, commerce("trial.granted.badge"))
        XCTAssertEqual(content.title, commerce("trial.granted.headline"))
        XCTAssertEqual(content.titleAccent, commerce("trial.granted.headline_accent"))
        XCTAssertEqual(content.subtitle, commerce("trial.granted.subtitle"))
    }

    func testTimelineMapsTodayHeadsUpAndDayFourteenChoice() {
        XCTAssertEqual(content.today.label, commerce("trial.timeline.today"))
        XCTAssertEqual(content.today.title, commerce("trial.timeline.today_title"))
        XCTAssertEqual(content.today.perks.map(\.title), [
            commerce("paywall.feature.app_blocking"),
            commerce("paywall.feature.shake"),
            commerce("paywall.feature.smart_reminders"),
            commerce("paywall.feature.custom_messages"),
        ])

        XCTAssertEqual(content.laterDays.map(\.label), [
            commerce("trial.granted.warning.label"),
            commerce("trial.granted.choice.label"),
        ])
        XCTAssertEqual(content.laterDays.map(\.title), [
            commerce("trial.granted.warning.title"),
            commerce("trial.granted.choice.title"),
        ])
        XCTAssertEqual(
            content.laterDays.map(\.detail),
            [
                commerce("trial.granted.warning.detail"),
                commerce("trial.granted.choice.detail"),
            ]
        )
    }

    func testGermanTrialGrantedMomentUsesCompleteIdiomaticCopy() {
        let germanLocale = Locale(identifier: "de_DE")
        let german = TrialGrantedMomentContent.localized(locale: germanLocale)

        XCTAssertEqual(german.badge, commerce("trial.granted.badge", locale: germanLocale))
        XCTAssertEqual(german.title, commerce("trial.granted.headline", locale: germanLocale))
        XCTAssertEqual(german.titleAccent, commerce("trial.granted.headline_accent", locale: germanLocale))
        XCTAssertEqual(german.laterDays.map(\.label), [
            commerce("trial.granted.warning.label", locale: germanLocale),
            commerce("trial.granted.choice.label", locale: germanLocale),
        ])
        XCTAssertEqual(german.laterDays.map(\.title), [
            commerce("trial.granted.warning.title", locale: germanLocale),
            commerce("trial.granted.choice.title", locale: germanLocale),
        ])
        XCTAssertEqual(
            german.laterDays.map(\.detail),
            [
                commerce("trial.granted.warning.detail", locale: germanLocale),
                commerce("trial.granted.choice.detail", locale: germanLocale),
            ]
        )
        XCTAssertEqual(german.primaryCTA, commerce("trial.granted.cta", locale: germanLocale))
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

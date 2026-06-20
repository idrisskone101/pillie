//
//  SoftPaywallContentTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class SoftPaywallContentTests: XCTestCase {
    func testSoftPaywallLeadsWithAppBlockingForDueActionTime() {
        let content = SoftPaywallContent.default

        XCTAssertEqual(content.title, "Stay on Track with")
        XCTAssertEqual(content.titleAccent, "Pillie Plus")

        // AC #1: the headline + benefits lead with app blocking for Due Action Time.
        XCTAssertTrue(
            content.subtitle.hasPrefix("Blocks distracting apps"),
            "Subtitle must lead with app blocking."
        )
        XCTAssertTrue(
            content.subtitle.lowercased().contains("reminder is due"),
            "Subtitle must tie the block to the Due Action Time."
        )
    }

    func testSoftPaywallComparisonContrastsTheFreeReminderPathWithPlusCapabilities() {
        let content = SoftPaywallContent.default

        XCTAssertEqual(content.comparisonLabel, "What you get")
        XCTAssertEqual(content.freeColumnLabel, "Free")
        XCTAssertEqual(content.plusColumnLabel, "Plus")
        XCTAssertEqual(content.rows.map(\.title), [
            "Daily reminders",
            "Block distracting apps",
            "Shake to confirm",
            "New perks as they launch"
        ])

        // The shared free path is reminders only; every Plus capability stays Plus-only.
        XCTAssertEqual(content.rows.filter(\.freeIncluded).map(\.title), ["Daily reminders"])
        XCTAssertTrue(content.rows.allSatisfy(\.plusIncluded))
    }

    func testSoftPaywallKeepsAClearTruthfulFreeAndTrialPath() {
        let content = SoftPaywallContent.default

        // The annual trial genuinely charges nothing up front.
        XCTAssertEqual(content.reassurances, ["No payment due now", "Cancel anytime"])

        // The monthly plan bills immediately, so its reassurances must never claim
        // there is "no payment due now".
        XCTAssertTrue(content.monthlyReassurances.contains("Cancel anytime"))
        XCTAssertFalse(
            content.monthlyReassurances.contains { $0.lowercased().contains("no payment due now") },
            "Monthly bills today — it must not promise 'no payment due now'."
        )

        XCTAssertEqual(content.primaryCTA, "Try Pillie Plus for free")
        XCTAssertEqual(content.freeCTA, "Continue with free plan")
        XCTAssertEqual(content.restoreCTA, "Restore Purchases")

        // Only the annual plan carries the 7-day trial, so the monthly CTA must never
        // promise something "free".
        XCTAssertFalse(content.monthlyCTA.lowercased().contains("free"))
    }

    func testSoftPaywallCopyAvoidsFakeUrgencyFakeStatsAndMedicalClaims() {
        let visibleCopy = SoftPaywallContent.default.visibleCopy
            .joined(separator: " ")
            .lowercased()

        for banned in [
            "limited offer", "act now", "hurry", "only today", "don't miss", "ends soon",
            "% of users", "studies show", "clinically", "doctor", "medical", "guaranteed",
            "credit card", "google pay", "no ads", "habit mastery"
        ] {
            XCTAssertFalse(
                visibleCopy.contains(banned),
                "Paywall copy must not contain '\(banned)'."
            )
        }
    }

    func testFreePlanConfirmationContentConfirmsFreeFeaturesWithoutAnotherUpgradeAsk() {
        let content = FreePlanConfirmationContent.default

        XCTAssertEqual(content.title, "You're all set with")
        XCTAssertEqual(content.titleAccent, "Pillie")
        XCTAssertEqual(content.primaryCTA, "Start Using Pillie")
        // Verified-seal hero redesign confirms the two free pillars (reminders +
        // tracking); the old "Smart reminders" card was dropped.
        XCTAssertEqual(content.confirmations.map(\.title), [
            "Daily reminders",
            "Cycle tracking"
        ])

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertTrue(visibleCopy.contains("active"))
        XCTAssertTrue(visibleCopy.contains("tracking"))
        XCTAssertFalse(visibleCopy.contains("app blocking"))
        XCTAssertFalse(visibleCopy.contains("screen time"))
        XCTAssertFalse(visibleCopy.contains("upgrade"))
        XCTAssertFalse(visibleCopy.contains("pillie plus"))
        XCTAssertFalse(visibleCopy.contains("limited offer"))
    }
}

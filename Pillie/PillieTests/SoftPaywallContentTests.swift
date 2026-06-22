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
            "Smart Reminders",
            "Block distracting apps",
            "Shake to confirm",
            "Custom reminder messages",
            "New perks as they launch"
        ])

        // The shared free path is reminders only; every Plus capability stays Plus-only.
        XCTAssertEqual(content.rows.filter(\.freeIncluded).map(\.title), ["Daily reminders"])
        XCTAssertTrue(content.rows.allSatisfy(\.plusIncluded))
    }

    func testSoftPaywallSmartRemindersRowFramesTheFollowUpEscalationAsPlusOnly() {
        let content = SoftPaywallContent.default
        let titles = content.rows.map(\.title)

        // The Smart Reminders row sits directly after the free Daily reminders row so the
        // free-vs-Plus contrast between the two is legible (ADR 0004).
        guard let dailyIndex = titles.firstIndex(of: "Daily reminders"),
              let smartIndex = titles.firstIndex(of: "Smart Reminders") else {
            return XCTFail("Both the daily and smart reminder rows must exist.")
        }
        XCTAssertEqual(smartIndex, dailyIndex + 1, "Smart Reminders must be adjacent to Daily reminders.")

        let smart = content.rows[smartIndex]
        XCTAssertFalse(smart.freeIncluded, "Smart Reminders is Plus-only.")
        XCTAssertTrue(smart.plusIncluded)

        // Copy reads as the same-day follow-up escalation, distinct from the base daily reminder.
        let detail = (smart.detail ?? "").lowercased()
        XCTAssertTrue(
            detail.contains("until you log it"),
            "Smart Reminders copy must frame the follow-up escalation, not the base reminder."
        )

        // No medical/efficacy/"never miss" claims (ADR 0002 trust constraints).
        for banned in ["never miss", "guarantee", "clinically", "medical", "doctor", "efficacy"] {
            XCTAssertFalse(detail.contains(banned), "Smart Reminders copy must avoid '\(banned)'.")
        }
    }

    func testSoftPaywallSurfacesCustomReminderMessagesAsAPlusOnlyRowAboveTheCatchAll() {
        let content = SoftPaywallContent.default
        let titles = content.rows.map(\.title)

        // The Custom reminder messages row sits directly above the "New perks" catch-all
        // as a supporting Plus perk — app blocking stays the hero (issue #109).
        guard let customIndex = titles.firstIndex(of: "Custom reminder messages"),
              let catchAllIndex = titles.firstIndex(of: "New perks as they launch") else {
            return XCTFail("Both the custom reminder messages and catch-all rows must exist.")
        }
        XCTAssertEqual(
            customIndex,
            catchAllIndex - 1,
            "Custom reminder messages must sit directly above the New perks catch-all."
        )

        let custom = content.rows[customIndex]
        XCTAssertFalse(custom.freeIncluded, "Custom reminder messages is Plus-only.")
        XCTAssertTrue(custom.plusIncluded)
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

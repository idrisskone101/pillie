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

        // The comparison row stays a single, subheading-free line — the escalation framing
        // lives in the dedicated upsell copy, not the paywall comparison list.
        XCTAssertNil(smart.detail, "Smart Reminders comparison row must not carry a subheading.")
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
        XCTAssertNil(custom.detail, "Custom reminder messages comparison row must not carry a subheading.")
    }

    func testSoftPaywallSellsACleanDirectBuyWithNoTrialPromise() {
        let content = SoftPaywallContent.default

        // Reverse Trial (ADR 0007 / issue #162): the StoreKit intro offer is gone, so
        // both plans bill immediately — no surface may claim "no payment due now".
        XCTAssertEqual(content.reassurances, ["Cancel anytime"])
        XCTAssertEqual(content.monthlyReassurances, ["Cancel anytime", "No commitment"])

        XCTAssertEqual(content.primaryCTA, "Unlock Pillie Plus")
        XCTAssertEqual(content.freeCTA, "Continue with free plan")
        XCTAssertEqual(content.restoreCTA, "Restore Purchases")

        // Neither purchase CTA may promise something "free" — a direct buy charges today.
        XCTAssertFalse(content.primaryCTA.lowercased().contains("free"))
        XCTAssertFalse(content.monthlyCTA.lowercased().contains("free"))

        // The plan-card labels live in the content model (not hardcoded in the view) so
        // the banned-copy sweep can see them; the old view-only "Annual Trial" label is
        // exactly how trial copy escaped the test net.
        XCTAssertEqual(content.annualPlanLabel, "Annual")
        XCTAssertEqual(content.monthlyPlanLabel, "Monthly")
        XCTAssertTrue(content.visibleCopy.contains(content.annualPlanLabel))
        XCTAssertTrue(content.visibleCopy.contains(content.monthlyPlanLabel))
    }

    func testSoftPaywallCopyAvoidsFakeUrgencyFakeStatsAndMedicalClaims() {
        let visibleCopy = SoftPaywallContent.default.visibleCopy
            .joined(separator: " ")
            .lowercased()

        for banned in [
            "limited offer", "act now", "hurry", "only today", "don't miss", "ends soon",
            "% of users", "studies show", "clinically", "doctor", "medical", "guaranteed",
            "credit card", "google pay", "no ads", "habit mastery",
            // Reverse Trial (issue #162): the StoreKit intro offer is gone, so no
            // surface may promise a trial or a payment-free start.
            "trial", "7-day", "no payment due now"
        ] {
            XCTAssertFalse(
                visibleCopy.contains(banned),
                "Paywall copy must not contain '\(banned)'."
            )
        }
    }

    // The FreePlanConfirmationContent test left with the view it covered: the
    // free-plan confirmation branch was retired by the Reverse Trial
    // (issue #164 / ADR 0007) — the Trial Granted Moment replaced the paywall
    // and everyone flows into the Screen Time branch.
}

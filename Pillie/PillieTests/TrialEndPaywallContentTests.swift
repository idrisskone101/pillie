//
//  TrialEndPaywallContentTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for the Trial-End
//  Paywall's cohort selection and own-stats assembly (issue #169 / ADR 0007).
//  Mirrors TrialStatusPresentationTests: fixed calendar, pure inputs,
//  boundary days.
//

import XCTest

@testable import Pillie

final class TrialEndPaywallContentTests: XCTestCase {
    func testRestoreWithoutAnActiveEntitlementIsNotACompletedRestore() {
        XCTAssertEqual(
            RestoreAccessOutcome.resolve(hasEntitlement: false),
            .missingPurchase
        )
        XCTAssertEqual(
            RestoreAccessOutcome.resolve(hasEntitlement: true),
            .restored
        )
    }

    func testCancellationNoteOnlyAppearsForSubscriptionPurchases() {
        XCTAssertTrue(TrialEndSuccessOutcome.purchased(.annual).showsCancellationNote)
        XCTAssertTrue(TrialEndSuccessOutcome.purchased(.monthly).showsCancellationNote)
        XCTAssertFalse(TrialEndSuccessOutcome.purchased(.lifetime).showsCancellationNote)
        XCTAssertFalse(TrialEndSuccessOutcome.restored.showsCancellationNote)
    }

    func testRestoredEntitlementSuccessUsesGenericPriceFreeLabel() {
        XCTAssertEqual(
            TrialEndSuccessOutcome.restored.label(
                annual: "$29.99 / year",
                monthly: "$4.99 / month",
                lifetime: "Pillie Plus Lifetime · $69.99",
                restored: "Pillie Plus access restored"
            ),
            "Pillie Plus access restored"
        )
    }

    func testPresentedPaywallSnapshotSurvivesEntitlementRemovingLiveContent() {
        guard let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: false,
            stats: .none,
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        ) else {
            return XCTFail("Expected expired-trial content")
        }
        var presentation = TrialEndPaywallPresentationState()
        presentation.present(content)

        let liveContentAfterPurchase = TrialEndPaywallContent.make(
            state: expiredState(hasEntitlement: true),
            blockerConfigSaved: false,
            stats: .none,
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        XCTAssertNil(liveContentAfterPurchase)
        XCTAssertEqual(presentation.presentedContent, content)
    }

    private let english = Locale(identifier: "en_US")

    /// Fixed local calendar so boundary expectations are deterministic.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    // Granted 2026-06-21 10:00 → full days June 22 – July 5, expiry July 6 00:00.
    private func expiredState(hasEntitlement: Bool = false) -> PlusAccessState {
        PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: date(2026, 6, 21, 10, 0))
    }

    /// First moment without protection: the local day after the last protected day.
    private var firstExpiredMorning: Date { date(2026, 7, 6, 9, 0) }

    private func fullStats(
        blocks: Int? = 23, taken: Int? = 13, due: Int? = 14, streak: Int? = 9
    ) -> TrialEndOwnStats {
        TrialEndOwnStats(
            blocksIntercepted: blocks,
            dosesTaken: taken,
            dosesDue: due,
            currentStreak: streak
        )
    }

    // MARK: - Tracer bullet: expired blocker-configured trial gets the loss-framed sheet

    func testExpiredTrialWithBlockerConfigProducesLossFramedContent() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        XCTAssertEqual(content?.cohort, .blockerConfigured)
        XCTAssertEqual(content?.primaryCTA, "Keep my protection")
    }

    // MARK: - Loss-framed copy + record card (design 2a)

    func testLossFramedHeadlineAndAsideWithInterceptedBlocks() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        XCTAssertEqual(content?.title, "That was Plus,")
        XCTAssertEqual(content?.titleAccent, "working for you.")
        XCTAssertEqual(content?.handwrittenAside, "worth keeping, right?")
    }

    func testRecordCardCarriesAllThreeRowsWithRealStats() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(blocks: 23, taken: 13, due: 14, streak: 9),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        guard case .record(let kicker, _, let rows, let quietShieldNote)? = content?.card else {
            return XCTFail("Expected the own-record card, got \(String(describing: content?.card))")
        }
        XCTAssertEqual(kicker, "Your 14-day record")
        XCTAssertNil(quietShieldNote)
        XCTAssertEqual(rows, [
            TrialEndPaywallContent.RecordRow(
                label: "Blocks intercepted", value: "23", valueSuffix: nil, emphasized: true
            ),
            TrialEndPaywallContent.RecordRow(
                label: "Doses on time", value: "13", valueSuffix: "of 14", emphasized: false
            ),
            TrialEndPaywallContent.RecordRow(
                label: "Current streak", value: "🔥 9 days", valueSuffix: nil, emphasized: false
            ),
        ])
    }

    func testRecordCardDateRangeSpansGrantDayToLastProtectedDay() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        guard case .record(_, let dateRange, _, _)? = content?.card else {
            return XCTFail("Expected the own-record card")
        }
        // Granted Jun 21, last protected day Jul 5 (expiry Jul 6 00:00).
        XCTAssertEqual(dateRange, "Jun 21 – Jul 5")
    }

    func testEnglishUKKeepsGenericEnglishCopyAndUsesBritishDateOrder() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertEqual(content?.title, "That was Plus,")
        guard case .record(_, let dateRange, _, _)? = content?.card else {
            return XCTFail("Expected the own-record card")
        }
        XCTAssertEqual(dateRange, "21 Jun – 5 Jul")
    }

    // MARK: - Zero-blocks fallback (design 2c)

    func testZeroBlocksDropsTheCounterRowAndReframesTheQuietShield() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(blocks: 0),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        // Zero blocks is never shown as a brag — the headline reframes instead.
        XCTAssertEqual(content?.title, "Your quiet")
        XCTAssertEqual(content?.titleAccent, "safety net.")
        XCTAssertEqual(content?.handwrittenAside, "quiet shield, strong streak")

        guard case .record(_, _, let rows, let quietShieldNote)? = content?.card else {
            return XCTFail("Expected the own-record card")
        }
        XCTAssertEqual(rows.map(\.label), ["Doses on time", "Current streak"])
        XCTAssertEqual(
            quietShieldNote,
            "Your blocker stood guard all 14 days — it never had to step in. That's the good outcome."
        )
    }

    func testUnknownBlocksDropsTheRowWithoutTheQuietShieldNote() {
        // `nil` means unknown, not zero: no row, but no "never had to step in"
        // claim either — that would be an unverifiable brag (ADR 0002).
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(blocks: nil),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        XCTAssertEqual(content?.title, "That was Plus,")
        guard case .record(_, _, let rows, let quietShieldNote)? = content?.card else {
            return XCTFail("Expected the own-record card")
        }
        XCTAssertEqual(rows.map(\.label), ["Doses on time", "Current streak"])
        XCTAssertNil(quietShieldNote)
    }

    func testZeroDosesOnTimeDropsTheDosesRow() {
        // "0 of 8" on a paywall is a zero brag, not a keep-your-protection
        // anchor — the row drops like any other unusable stat.
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(blocks: 23, taken: 0, due: 8, streak: 0),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        guard case .record(_, _, let rows, _)? = content?.card else {
            return XCTFail("Expected the own-record card")
        }
        XCTAssertEqual(rows.map(\.label), ["Blocks intercepted"])
    }

    // MARK: - Gain-framed cohort (design 2b)

    func testReminderOnlyCohortGetsGainFramedPerksAndFreeForeverHeadline() {
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: false,
            stats: .none,
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        XCTAssertEqual(content?.cohort, .reminderOnly)
        XCTAssertEqual(content?.title, "Reminders are")
        XCTAssertEqual(content?.titleAccent, "free. Forever.")
        XCTAssertEqual(content?.primaryCTA, "Unlock Pillie Plus")
        XCTAssertEqual(content?.handwrittenAside, "whenever you're ready!")

        guard case .perks(let kicker, let chips, _)? = content?.card else {
            return XCTFail("Expected the perks card, got \(String(describing: content?.card))")
        }
        XCTAssertEqual(kicker, "What Plus adds")
        // The same four perks the Trial Granted Moment promised.
        XCTAssertEqual(chips, ["App blocking", "Shake to confirm", "Smart Reminders", "Custom messages"])
    }

    // MARK: - Missing stats fall back gracefully

    func testBlockerCohortWithNoUsableStatsFallsBackToPerksCard() {
        // All stats missing (or zero-streak): nothing honest to anchor loss
        // framing on, so the record card gives way to the perks card — never a
        // wall of zeros. Framing and CTA stay loss-cohort.
        let content = TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(blocks: nil, taken: nil, due: nil, streak: 0),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        )

        XCTAssertEqual(content?.cohort, .blockerConfigured)
        XCTAssertEqual(content?.primaryCTA, "Keep my protection")
        guard case .perks? = content?.card else {
            return XCTFail("Expected the perks fallback, got \(String(describing: content?.card))")
        }
    }

    // MARK: - Gating: when the sheet must not exist

    func testActiveTrialProducesNoContent() {
        XCTAssertNil(TrialEndPaywallContent.make(
            state: expiredState(),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: date(2026, 7, 5, 9, 0), // last protected day — still active
            locale: english
        ))
    }

    func testEntitledUserProducesNoContent() {
        XCTAssertNil(TrialEndPaywallContent.make(
            state: expiredState(hasEntitlement: true),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        ))
    }

    func testNeverGrantedProducesNoContent() {
        XCTAssertNil(TrialEndPaywallContent.make(
            state: PlusAccessState(hasEntitlement: false, trialGrantDate: nil),
            blockerConfigSaved: true,
            stats: fullStats(),
            calendar: calendar,
            now: firstExpiredMorning,
            locale: english
        ))
    }
}

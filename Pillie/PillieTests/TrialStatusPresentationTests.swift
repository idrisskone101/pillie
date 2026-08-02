//
//  TrialStatusPresentationTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest) for the in-trial
//  indicator + status sheet presentation (issue #166 / ADR 0007). Mirrors
//  ReverseTrialClockTests: fixed calendar, pure inputs, boundary days.
//

import XCTest

@testable import Pillie

final class TrialStatusPresentationTests: XCTestCase {

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

    // Granted 2026-07-01 10:00 → full days July 2–15, expiry July 16 00:00.
    private func trialState(hasEntitlement: Bool = false) -> PlusAccessState {
        PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: date(2026, 7, 1, 10, 0))
    }

    // MARK: - Tracer bullet: an active trial surfaces the indicator

    func testActiveTrialProducesIndicatorWithDaysRemaining() {
        // Day 1 (first full day): 14 rollovers left.
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0)
        )

        XCTAssertEqual(presentation?.daysRemaining, 14)
    }

    func testActiveTrialWithProtectionShowsTruthfulProtectionStatus() {
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            protectionActive: true,
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0)
        )

        XCTAssertEqual(presentation?.indicatorLabel, "Protection active · 14 days left")
    }

    func testActiveTrialWithoutProtectionShowsTruthfulSetupStatus() {
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            protectionActive: false,
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0)
        )

        XCTAssertEqual(presentation?.indicatorLabel, "Set up protection · 14 days left")
    }

    // MARK: - Indicator label (day-count boundaries)

    func testIndicatorLabelCountsDownAcrossTheTrial() {
        func label(onDay day: Int) -> String? {
            TrialStatusPresentation.make(
                state: trialState(),
                calendar: calendar,
                now: date(2026, 7, 1 + day, 9, 0)
            )?.indicatorLabel
        }

        // Day 1 (first full day).
        XCTAssertEqual(label(onDay: 1), "Set up protection · 14 days left")
        // Day 13 (the day before the last protected day).
        XCTAssertEqual(label(onDay: 13), "Set up protection · 2 days left")
    }

    func testGrantDayLabelClampsToFourteenDays() {
        // The partial grant day has 15 rollovers left, but the trial promises
        // "14 days free" — never show a count above the promise.
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 1, 10, 30)
        )

        XCTAssertEqual(presentation?.indicatorLabel, "Set up protection · 14 days left")
    }

    func testFinalProtectedDayReadsEndsTonight() {
        // July 15 is the last protected day (expiry July 16 00:00). The whole
        // day is still fully covered, so the honest copy is "ends tonight" —
        // never "0 days left" while active, and never a plural "1 days left".
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 15, 22, 0)
        )

        XCTAssertEqual(presentation?.indicatorLabel, "Set up protection · ends tonight")
        XCTAssertEqual(presentation?.endsTonight, true)
    }

    // MARK: - Status sheet content

    func testSheetContentExplainsRemainingTimeExpiryAndKeepPlusPath() {
        let content = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0)
        )?.sheetContent

        XCTAssertEqual(content?.title, "14 days left in your Plus trial")
        // What expiry changes: blocking off, reminders stay free, setup kept.
        XCTAssertEqual(content?.expiryRows.map(\.text), [
            "App blocking turns off",
            "Reminders stay free, forever",
            "Your blocker setup is saved",
        ])
        // The quiet buy-early path into the existing purchase flow.
        XCTAssertEqual(content?.ctaTitle, "Keep Pillie Plus")
    }

    func testHardPaywallSheetExplainsThatPaidAccessIsRequiredAtExpiry() {
        let content = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: Locale(identifier: "en_US"),
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )?.sheetContent

        XCTAssertEqual(content?.expiryRows.map(\.text), [
            "Pillie Plus access pauses",
            "Choose monthly, annual, or lifetime to continue",
            "Your blocker setup is saved",
        ])
        XCTAssertEqual(content?.expiryRows.map(\.symbol), [
            "lock.fill",
            "creditcard.fill",
            "checkmark.circle.fill",
        ])
    }

    func testHardPaywallExpiryRowsStructurallyPairCopyAndSymbols() {
        let rows = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: Locale(identifier: "en_US"),
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )?.sheetContent.expiryRows

        XCTAssertEqual(rows, [
            TrialExpiryRow(text: "Pillie Plus access pauses", symbol: "lock.fill"),
            TrialExpiryRow(
                text: "Choose monthly, annual, or lifetime to continue",
                symbol: "creditcard.fill"
            ),
            TrialExpiryRow(
                text: "Your blocker setup is saved",
                symbol: "checkmark.circle.fill"
            ),
        ])
    }

    // MARK: - Activation hub (#219)

    func testUnconfiguredTrialRecommendsAppBlockingFirst() {
        let content = TrialStatusPresentation(daysRemaining: 14).sheetContent(
            for: TrialActivationState(
                appBlockingActive: false,
                customMessagesCustomized: false,
                smartRemindersCustomized: false
            )
        )

        XCTAssertEqual(content.activationItems, [
            TrialActivationItem(
                feature: .appBlocking,
                title: "App blocking",
                status: .setUp,
                action: .appBlocking,
                isRecommended: true
            ),
            TrialActivationItem(
                feature: .smartReminders,
                title: "Smart Reminders",
                status: .activeAutomatically,
                action: .smartReminders,
                isRecommended: false
            ),
            TrialActivationItem(
                feature: .customMessages,
                title: "Custom messages",
                status: .personalize,
                action: .customMessages,
                isRecommended: false
            ),
            TrialActivationItem(
                feature: .shakeToConfirm,
                title: "Shake to confirm",
                status: .on,
                action: nil,
                isRecommended: false
            ),
        ])
    }

    func testConfiguredBlockingRecommendsCustomMessagesNext() {
        let content = TrialStatusPresentation(daysRemaining: 14).sheetContent(
            for: TrialActivationState(
                appBlockingActive: true,
                customMessagesCustomized: false,
                smartRemindersCustomized: false
            )
        )

        XCTAssertEqual(
            content.activationItems.first(where: \.isRecommended)?.action,
            .customMessages
        )
    }

    func testCustomizedMessagesRecommendSmartRemindersLast() {
        let content = TrialStatusPresentation(daysRemaining: 14).sheetContent(
            for: TrialActivationState(
                appBlockingActive: true,
                customMessagesCustomized: true,
                smartRemindersCustomized: false
            )
        )

        XCTAssertEqual(
            content.activationItems.first(where: \.isRecommended)?.action,
            .smartReminders
        )
    }

    func testFullyConfiguredTrialStillPrioritizesOneAdjustableAction() {
        let content = TrialStatusPresentation(daysRemaining: 14).sheetContent(
            for: TrialActivationState(
                appBlockingActive: true,
                customMessagesCustomized: true,
                smartRemindersCustomized: true
            )
        )

        XCTAssertEqual(content.activationItems.map(\.status), [
            .active, .customized, .customized, .on,
        ])
        XCTAssertEqual(
            content.activationItems.filter(\.isRecommended).map(\.action),
            [.smartReminders]
        )
    }

    func testSheetTitleOnFinalDayReadsEndsTonight() {
        let content = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 15, 22, 0)
        )?.sheetContent

        XCTAssertEqual(content?.title, "Your Plus trial ends tonight")
    }

    // MARK: - No indicator for entitled users, expired trials, or no trial

    func testEntitledUserMidTrialGetsNoIndicator() {
        // Purchasing during the trial must remove the indicator immediately,
        // even though the trial clock is still running.
        let presentation = TrialStatusPresentation.make(
            state: trialState(hasEntitlement: true),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0)
        )

        XCTAssertNil(presentation)
    }

    func testExpiredTrialGetsNoIndicator() {
        // Expiry midnight (July 16 00:00) and beyond: indicator is gone.
        XCTAssertNil(TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 16, 0, 0)
        ))
        XCTAssertNil(TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 8, 20, 12, 0)
        ))
    }

    func testNoTrialEverGrantedGetsNoIndicator() {
        XCTAssertNil(TrialStatusPresentation.make(
            state: PlusAccessState(hasEntitlement: false, trialGrantDate: nil),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0)
        ))
    }
}

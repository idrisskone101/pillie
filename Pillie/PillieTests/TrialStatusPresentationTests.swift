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
    private let english = Locale(identifier: "en_US")

    private func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: english)
    }

    private func commerce(_ key: String, days: Int) -> String {
        PillieLocalization.formatted(
            key,
            table: "Commerce",
            locale: english,
            arguments: Int64(days)
        )
    }

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
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )

        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.active", days: 14)
        )
    }

    func testActiveTrialWithoutProtectionShowsTruthfulSetupStatus() {
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            protectionActive: false,
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )

        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.setup", days: 14)
        )
    }

    // MARK: - Indicator label (day-count boundaries)

    func testIndicatorLabelCountsDownAcrossTheTrial() {
        func label(onDay day: Int) -> String? {
            TrialStatusPresentation.make(
                state: trialState(),
                calendar: calendar,
                now: date(2026, 7, 1 + day, 9, 0),
                locale: english
            )?.indicatorLabel
        }

        // Day 1 (first full day).
        XCTAssertEqual(label(onDay: 1), commerce("trial.status.indicator.setup", days: 14))
        // Day 13 (the day before the last protected day).
        XCTAssertEqual(label(onDay: 13), commerce("trial.status.indicator.setup", days: 2))
    }

    func testGrantDayLabelClampsToFourteenDays() {
        // The partial grant day has 15 rollovers left, but the trial promises
        // "14 days free" — never show a count above the promise.
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 1, 10, 30),
            locale: english
        )

        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.setup", days: 14)
        )
    }

    func testFinalProtectedDayReadsEndsTonight() {
        // July 15 is the last protected day (expiry July 16 00:00). The whole
        // day is still fully covered, so the honest copy is "ends tonight" —
        // never "0 days left" while active, and never a plural "1 days left".
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 15, 22, 0),
            locale: english
        )

        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.setup_tonight")
        )
        XCTAssertEqual(presentation?.endsTonight, true)
    }

    // MARK: - Status sheet content

    func testSheetContentExplainsRemainingTimeExpiryAndKeepPlusPath() {
        let now = date(2026, 7, 2, 9, 0)
        let content = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: now,
            locale: english
        )?.sheetContent

        let expiry = ReverseTrialClock(grantDate: date(2026, 7, 1, 10, 0))
            .expiryMoment(calendar: calendar)
        XCTAssertEqual(
            content?.title,
            CommercePresentation.trialEndText(date: expiry, locale: english)
        )
        XCTAssertEqual(content?.expiryRows.map(\.text), [
            commerce("trial.status.after.blocking_off"),
            commerce("trial.status.after.reminders_free"),
            commerce("trial.status.after.setup_saved"),
        ])
        XCTAssertEqual(content?.ctaTitle, commerce("trial.status.keep_plus"))
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
            commerce("trial.status.after.plus_pauses"),
            commerce("trial.status.after.plan_required"),
            commerce("trial.status.after.setup_saved"),
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
            TrialExpiryRow(text: commerce("trial.status.after.plus_pauses"), symbol: "lock.fill"),
            TrialExpiryRow(
                text: commerce("trial.status.after.plan_required"),
                symbol: "creditcard.fill"
            ),
            TrialExpiryRow(
                text: commerce("trial.status.after.setup_saved"),
                symbol: "checkmark.circle.fill"
            ),
        ])
    }

    // MARK: - Activation hub (#219)

    func testUnconfiguredTrialRecommendsAppBlockingFirst() {
        let content = TrialStatusPresentation(
            daysRemaining: 14,
            locale: english
        ).sheetContent(
            for: TrialActivationState(
                appBlockingActive: false,
                customMessagesCustomized: false,
                smartRemindersCustomized: false
            )
        )

        XCTAssertEqual(content.activationItems, [
            TrialActivationItem(
                feature: .appBlocking,
                title: commerce("paywall.feature.app_blocking.compact"),
                status: .setUp,
                action: .appBlocking,
                isRecommended: true,
                locale: english
            ),
            TrialActivationItem(
                feature: .smartReminders,
                title: commerce("paywall.feature.smart_reminders"),
                status: .activeAutomatically,
                action: .smartReminders,
                isRecommended: false,
                locale: english
            ),
            TrialActivationItem(
                feature: .customMessages,
                title: commerce("paywall.feature.custom_messages.compact"),
                status: .personalize,
                action: .customMessages,
                isRecommended: false,
                locale: english
            ),
            TrialActivationItem(
                feature: .shakeToConfirm,
                title: commerce("paywall.feature.shake"),
                status: .on,
                action: nil,
                isRecommended: false,
                locale: english
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
            now: date(2026, 7, 15, 22, 0),
            locale: english
        )?.sheetContent

        let expiry = ReverseTrialClock(grantDate: date(2026, 7, 1, 10, 0))
            .expiryMoment(calendar: calendar)
        XCTAssertEqual(
            content?.title,
            CommercePresentation.trialEndText(date: expiry, locale: english)
        )
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

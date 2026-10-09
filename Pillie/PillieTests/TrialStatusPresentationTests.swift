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

    func testActiveTrialWithoutProtectionShowsPlainCountdown() {
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            protectionActive: false,
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )

        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.countdown", days: 14)
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
        XCTAssertEqual(label(onDay: 1), commerce("trial.status.indicator.countdown", days: 14))
        // Day 13 (the day before the last protected day).
        XCTAssertEqual(label(onDay: 13), commerce("trial.status.indicator.countdown", days: 2))
    }

    func testEveOfBreakWeekBadgeStaysFourteenThroughEveryPlaceboDay() {
        let grant = date(2026, 7, 1, 10, 0)
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: grant,
            schedule: ActiveDaySchedule(
                anchorDate: grant,
                anchorDayIndex: 20,
                activeDays: 21,
                cycleLength: 28
            )
        )
        let calendarOnly = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: grant
        )

        for day in 2...8 {
            let now = date(2026, 7, day, 12, 0)
            let presentation = TrialStatusPresentation.make(
                state: state,
                protectionActive: true,
                calendar: calendar,
                now: now,
                locale: english
            )
            XCTAssertEqual(presentation?.displayedDaysRemaining, 14)
            XCTAssertEqual(
                presentation?.indicatorLabel,
                commerce("trial.status.indicator.active", days: 14)
            )
            XCTAssertEqual(presentation?.endsTonight, false)
        }

        let burned = TrialStatusPresentation.make(
            state: calendarOnly,
            protectionActive: true,
            calendar: calendar,
            now: date(2026, 7, 8, 12, 0),
            locale: english
        )
        XCTAssertEqual(burned?.displayedDaysRemaining, 8)
        XCTAssertEqual(
            burned?.indicatorLabel,
            commerce("trial.status.indicator.active", days: 8)
        )
    }

    func testGrantDayLabelClampsToFourteenDays() {
        // The partial grant day has 15 rollovers left, but the trial promises
        // "14 active days free" — never show a count above the promise.
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 1, 10, 30),
            locale: english
        )

        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.countdown", days: 14)
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
            commerce("trial.status.indicator.countdown_tonight")
        )
        XCTAssertEqual(presentation?.endsTonight, true)
    }

    // MARK: - Status sheet content (ENG-135: status + commerce only)

    func testUnconfiguredBadgeReadsPlainCountdown() {
        let presentation = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )

        XCTAssertEqual(presentation?.indicatorLabel, "14 active days left")
    }

    func testSheetContentShowsCountdownExpiryProgressAndKeepPlusPath() throws {
        let content = try XCTUnwrap(TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )?.sheetContent)

        XCTAssertEqual(content.eyebrow, "Pillie Plus trial")
        XCTAssertEqual(content.headline, "14 active days left")
        XCTAssertEqual(content.until, "Everything in Plus is yours until July 16.")
        XCTAssertEqual(content.progress, TrialProgress(
            filledDays: 1,
            totalDays: 14,
            todayLabel: "Day 1",
            endLabel: "Jul 16"
        ))
        XCTAssertEqual(content.timelineTitle, "What happens next")
        XCTAssertEqual(content.ctaTitle, "Keep Pillie Plus")
    }

    func testProgressCountsElapsedDaysAndFillsOnTheLastDay() {
        func progress(on day: Int) -> TrialProgress? {
            TrialStatusPresentation.make(
                state: trialState(),
                calendar: calendar,
                now: date(2026, 7, day, 9, 0),
                locale: english
            )?.sheetContent.progress
        }

        // Grant day and the first full day both read Day 1 beside "14 left".
        XCTAssertEqual(progress(on: 1)?.filledDays, 1)
        XCTAssertEqual(progress(on: 2)?.filledDays, 1)
        XCTAssertEqual(progress(on: 8)?.todayLabel, "Day 7")
        XCTAssertEqual(progress(on: 15)?.filledDays, 14)
    }

    func testTimelineDatesComeFromPlannerNoticeSlotsAndTheExpiryDay() throws {
        let rows = try XCTUnwrap(TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )?.sheetContent.timeline)

        // Granted July 1 → expiry July 16 00:00; day-10/13 notices 5 and 2 days before.
        XCTAssertEqual(rows.map(\.date), [
            date(2026, 7, 11, 0, 0),
            date(2026, 7, 14, 0, 0),
            date(2026, 7, 16, 0, 0),
        ])
        let expiry = ReverseTrialClock(grantDate: date(2026, 7, 1, 10, 0))
            .expiryMoment(calendar: calendar)
        let plannerDays = ReminderSchedulePlanner.trialNoticeSlots
            .filter { $0.calendarDaysBeforeExpiry > 0 }
            .compactMap { calendar.date(byAdding: .day, value: -$0.calendarDaysBeforeExpiry, to: expiry) }
        XCTAssertEqual(Array(rows.map(\.date).prefix(2)), plannerDays)

        XCTAssertEqual(rows.map(\.dateText), ["July 11", "July 14", "July 16"])
        XCTAssertEqual(rows.map(\.text), [
            "Pillie reminds you 5 days before it ends.",
            "A last reminder before your trial ends.",
            "App blocking turns off. Daily reminders stay free, and your setup stays saved.",
        ])
        XCTAssertEqual(rows.map(\.symbol), ["bell.fill", "bell.fill", "lock.fill"])
    }

    func testHardPaywallTimelineEndsWithPlusPausing() {
        let rows = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )?.sheetContent.timeline

        XCTAssertEqual(
            rows?.last?.text,
            "Plus pauses until you choose a plan. Your setup stays saved."
        )
    }

    func testBreakWeekMovesEveryTimelineDate() throws {
        let grant = date(2026, 7, 1, 10, 0)
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: grant,
            schedule: ActiveDaySchedule(
                anchorDate: grant,
                anchorDayIndex: 20,
                activeDays: 21,
                cycleLength: 28
            )
        )
        let rows = try XCTUnwrap(TrialStatusPresentation.make(
            state: state,
            calendar: calendar,
            now: date(2026, 7, 2, 9, 0),
            locale: english
        )?.sheetContent.timeline)

        // Seven placebo days push expiry from July 16 to July 23.
        XCTAssertEqual(rows.map(\.dateText), ["July 18", "July 21", "July 23"])
    }

    func testFinalDaySheetHeroReadsEndsTonight() {
        let content = TrialStatusPresentation.make(
            state: trialState(),
            calendar: calendar,
            now: date(2026, 7, 15, 22, 0),
            locale: english
        )?.sheetContent

        XCTAssertEqual(content?.headline, "Trial ends tonight")
        XCTAssertEqual(content?.progress.todayLabel, "Day 14")
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

    func testBreakDayWithOneCountedDayLeftDoesNotSayEndsTonight() {
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(2026, 7, 1, 9, 0),
            schedule: ActiveDaySchedule(
                anchorDate: date(2026, 7, 1, 9, 0),
                anchorDayIndex: 7,
                activeDays: 21,
                cycleLength: 28
            )
        )
        let presentation = TrialStatusPresentation.make(
            state: state,
            calendar: calendar,
            now: date(2026, 7, 15, 12, 0),
            locale: english
        )

        XCTAssertEqual(presentation?.daysRemaining, 1)
        XCTAssertEqual(presentation?.endsTonight, false)
        XCTAssertEqual(
            presentation?.indicatorLabel,
            commerce("trial.status.indicator.countdown", days: 1)
        )
    }
}

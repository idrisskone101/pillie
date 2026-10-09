//
//  RoutineDialCommitTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

// The Xcode 27 beta aborts hosted tests when an app-module class deallocates during
// a test, so stores, containers, recorders, and telemetry live for the process.
@MainActor private var retainedForProcessLifetime: [Any] = []

@MainActor
final class RoutineDialCommitTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    private struct Harness {
        let store: PillStore
        let recorder: DialCompletionRecorder
        let defaults: UserDefaults
        let telemetry: ProductAnalyticsTelemetry
        let now: Date

        func commit(_ pick: RoutineDialPick, pickedAt: Date? = nil) {
            TodayPillCommit.run(
                OnboardingDraft(pick: pick, pickedAt: pickedAt ?? now),
                store: store,
                now: now,
                defaults: defaults,
                telemetry: telemetry
            )
        }
    }

    private static let noon = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
    private static let afterReminder = InMemoryStoreFactory.localDate("2026-09-27", hour: 21, minute: 5)
    private static let reminderOpens = InMemoryStoreFactory.localDate("2026-09-27", hour: 20, minute: 30)

    private func makeHarness(now: Date, name: String = #function) throws -> Harness {
        PillieClock.setFixedNowForTesting(now)
        let fixture = try InMemoryStoreFactory.makeStore(now: now)
        fixture.store.reminderHour = 20
        fixture.store.reminderMinute = 0
        let recorder = DialCompletionRecorder()
        let suite = "RoutineDialCommitTests.\(name)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let telemetry = ProductAnalyticsTelemetry(
            analytics: recorder,
            isPlus: { false },
            acquisitionSource: { nil },
            trialTermsCohort: { nil }
        )
        retainedForProcessLifetime.append(contentsOf: [fixture, recorder, defaults, telemetry] as [Any])
        return Harness(store: fixture.store, recorder: recorder, defaults: defaults, telemetry: telemetry, now: now)
    }

    private func pick(_ method: RoutineDialMethod, _ cycleDay: Int, _ answer: TodayPillPick.Answer?) -> RoutineDialPick {
        RoutineDialPick(method: method, cycleDay: cycleDay, answer: answer)!
    }

    private static let patchActions: [Int: PillDay.ActionType] = [1: .patchChange, 8: .patchChange, 15: .patchChange, 22: .patchRemove]
    private static let ringActions: [Int: PillDay.ActionType] = [1: .ringInsert, 22: .ringRemove]

    private func expectedAction(_ method: RoutineDialMethod, _ cycleDay: Int) -> PillDay.ActionType {
        switch method {
        case .patch: Self.patchActions[cycleDay] ?? (cycleDay <= 21 ? .patchActive : .patchBreak)
        case .ring: Self.ringActions[cycleDay] ?? (cycleDay <= 21 ? .ringActive : .ringBreak)
        }
    }

    private func assertEveryDialDayLandsOnHome(_ method: RoutineDialMethod, now: Date, answer: TodayPillPick.Answer) throws {
        let harness = try makeHarness(now: now, name: "\(method).\(now.timeIntervalSince1970).\(answer)")
        let store = harness.store
        for cycleDay in 1...28 {
            let asks = RoutineDialDay.day(cycleDay, method: method).task != nil
            let pick = pick(method, cycleDay, asks ? answer : nil)
            PillieClock.setFixedNowForTesting(now)
            store.refreshDayContextIfNeeded()

            harness.commit(pick)

            if !pick.logsAnAction && now < Self.reminderOpens {
                PillieClock.setFixedNowForTesting(Self.reminderOpens)
                store.refreshDayContextIfNeeded()
            }
            let due = store.dueAction(on: store.today)
            XCTAssertEqual(due?.method, method.contraceptiveMethod, "\(method) day \(cycleDay)")
            XCTAssertEqual(due?.cycleDay, cycleDay, "\(method) day \(cycleDay)")
            XCTAssertEqual(due?.type, expectedAction(method, cycleDay), "\(method) day \(cycleDay)")
            XCTAssertEqual(store.statusForDate(store.today) == .taken, pick.logsAnAction, "\(method) day \(cycleDay)")
        }
    }

    func testEveryPatchDayLandsOnHomeWhenYesComesBeforeTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.patch, now: Self.noon, answer: .taken)
    }

    func testEveryPatchDayLandsOnHomeWhenYesComesAfterTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.patch, now: Self.afterReminder, answer: .taken)
    }

    func testEveryPatchDayLandsOnHomeWhenNotYetComesBeforeTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.patch, now: Self.noon, answer: .notYet)
    }

    func testEveryPatchDayLandsOnHomeWhenNotYetComesAfterTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.patch, now: Self.afterReminder, answer: .notYet)
    }

    func testEveryRingDayLandsOnHomeWhenYesComesBeforeTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.ring, now: Self.noon, answer: .taken)
    }

    func testEveryRingDayLandsOnHomeWhenYesComesAfterTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.ring, now: Self.afterReminder, answer: .taken)
    }

    func testEveryRingDayLandsOnHomeWhenNotYetComesBeforeTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.ring, now: Self.noon, answer: .notYet)
    }

    func testEveryRingDayLandsOnHomeWhenNotYetComesAfterTheReminder() throws {
        try assertEveryDialDayLandsOnHome(.ring, now: Self.afterReminder, answer: .notYet)
    }

    func testBeforeTheReminderHomeShowsTheNamedDayForAPickWithoutYes() throws {
        let harness = try makeHarness(now: Self.noon)

        harness.commit(pick(.patch, 10, nil))

        XCTAssertEqual(harness.store.dueAction(on: harness.store.today)?.cycleDay, 10)
        XCTAssertEqual(harness.store.pack.cycleDayIndex(on: Calendar.current.startOfDay(for: Self.noon)) + 1, 10)
    }

    func testRecommittingARingPickAfterAYesMovesTheSchedule() throws {
        let harness = try makeHarness(now: Self.afterReminder)

        harness.commit(pick(.ring, 1, .taken))
        harness.commit(pick(.ring, 10, nil))

        XCTAssertEqual(harness.store.dueAction(on: harness.store.today)?.cycleDay, 10)
        XCTAssertEqual(harness.store.dueAction(on: harness.store.today)?.type, .ringActive)
    }

    func testYesLogsTheChangeAndReportsTheOnboardingActionOnce() throws {
        let harness = try makeHarness(now: Self.afterReminder)

        harness.commit(pick(.patch, 8, .taken))
        harness.commit(pick(.patch, 8, .taken))

        XCTAssertTrue(harness.store.isTodayTaken)
        XCTAssertEqual(harness.store.contraceptiveMethod, .patch)
        XCTAssertEqual(harness.recorder.completions, [.onboarding])
    }

    func testNotYetLogsNothingAndReportsNothing() throws {
        let harness = try makeHarness(now: Self.afterReminder)

        harness.commit(pick(.ring, 22, .notYet))

        XCTAssertEqual(harness.store.todayDueAction?.type, .ringRemove)
        XCTAssertFalse(harness.store.isTodayTaken)
        XCTAssertEqual(harness.store.currentStreak, 0)
        XCTAssertEqual(harness.recorder.completions, [])
    }

    func testAPickFromYesterdayRollsToTodaysCycleDayUnlogged() throws {
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-26", hour: 12, minute: 24)
        let harness = try makeHarness(now: Self.noon)

        harness.commit(pick(.patch, 8, .taken), pickedAt: pickedAt)

        XCTAssertEqual(harness.store.pack.cycleDayIndex(on: harness.store.today) + 1, 9)
        XCTAssertFalse(harness.store.isTodayTaken)
        XCTAssertEqual(harness.recorder.completions, [])
    }

    func testANotYetAfterTheReminderIsStillTheOpenTaskPastMidnight() throws {
        let pastMidnight = InMemoryStoreFactory.localDate("2026-09-28", hour: 0, minute: 10)
        let harness = try makeHarness(now: pastMidnight)

        harness.commit(pick(.patch, 8, .notYet), pickedAt: Self.afterReminder)

        let store = harness.store
        XCTAssertEqual(store.today, Calendar.current.startOfDay(for: Self.afterReminder))
        XCTAssertEqual(store.dueAction(on: store.today)?.cycleDay, 8)
        XCTAssertEqual(store.dueAction(on: store.today)?.type, .patchChange)
        XCTAssertEqual(store.statusForDate(store.today), .upcoming)
    }

    func testClearDropsTheDialDraftAndTheReportedFlag() throws {
        let harness = try makeHarness(now: Self.afterReminder)
        pick(.ring, 1, .taken).save(to: harness.defaults)
        harness.commit(pick(.ring, 1, .taken))
        XCTAssertTrue(harness.defaults.bool(forKey: TodayPillCommit.reportedStorageKey))

        TodayPillCommit.clear(from: harness.defaults)

        XCTAssertNil(RoutineDialPick.load(from: harness.defaults))
        XCTAssertFalse(harness.defaults.bool(forKey: TodayPillCommit.reportedStorageKey))
    }

    func testContinueOnADialPickRestoredDaysLaterKeepsTheDayItNamed() throws {
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-25", hour: 12, minute: 24)
        let harness = try makeHarness(now: Self.noon)
        pick(.patch, 8, .taken).save(to: harness.defaults, at: pickedAt)

        // Resumed two days later, the dial restores the pick and Continue saves it again unchanged.
        try XCTUnwrap(RoutineDialPick.load(from: harness.defaults)).save(to: harness.defaults)
        TodayPillCommit.run(
            try XCTUnwrap(OnboardingDraft<RoutineDialPick>.load(from: harness.defaults)),
            store: harness.store,
            now: Self.noon,
            defaults: harness.defaults,
            telemetry: harness.telemetry
        )

        XCTAssertEqual(harness.store.pack.cycleDayIndex(on: harness.store.today) + 1, 10)
        XCTAssertFalse(harness.store.isTodayTaken)
    }

    // MARK: Review Prompt

    /// The decision Home reads for its Review Prompt card.
    private func reviewPrompt(_ harness: Harness) -> ReviewPromptEligibility.Decision {
        harness.store.homeReviewPromptDecision(higherPriorityCardShowing: false, defaults: harness.defaults)
    }

    private func clearReviewPromptHistory(_ store: PillStore) {
        store.reviewPromptPermanentlySuppressed = false
        store.reviewPromptLastSoftDismissal = nil
        store.reviewPromptSoftDismissalCount = 0
    }

    /// Home's button on a later day, after that day's 8 PM reminder.
    private func logOnHome(_ harness: Harness, on iso: String) {
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate(iso, hour: 21, minute: 5))
        harness.store.refreshDayContextIfNeeded()
        harness.store.markTodayAsTaken()
    }

    /// Day 8's change is logged in onboarding on 27 Sep; day 15 is 4 Oct.
    func testAPatchChangeLoggedInOnboardingWaitsForTheNextChangeBeforeTheReviewPrompt() throws {
        let harness = try makeHarness(now: Self.afterReminder)
        clearReviewPromptHistory(harness.store)

        harness.commit(pick(.patch, 8, .taken))

        XCTAssertEqual(harness.store.currentStreak, 1)
        XCTAssertEqual(reviewPrompt(harness), .suppressed(.ineligibleStreak))

        logOnHome(harness, on: "2026-10-04")

        XCTAssertEqual(harness.store.currentStreak, 2)
        XCTAssertEqual(reviewPrompt(harness), .show)
    }

    func testAPatchChangeLoggedOnHomeAfterNotYetOpensTheReviewPrompt() throws {
        let harness = try makeHarness(now: Self.afterReminder)
        clearReviewPromptHistory(harness.store)

        harness.commit(pick(.patch, 8, .notYet))
        logOnHome(harness, on: "2026-09-27")

        XCTAssertEqual(harness.store.currentStreak, 1)
        XCTAssertEqual(reviewPrompt(harness), .show)
    }

    /// Day 15 (4 Oct) is never logged, so the streak starts over with day 22's removal on 11 Oct.
    func testAPatchRemovalLoggedOnHomeAfterAMissedChangeOpensTheReviewPrompt() throws {
        let harness = try makeHarness(now: Self.afterReminder)
        clearReviewPromptHistory(harness.store)
        harness.commit(pick(.patch, 8, .taken))

        logOnHome(harness, on: "2026-10-11")

        XCTAssertEqual(harness.store.statusForDate(InMemoryStoreFactory.localDate("2026-10-04", hour: 0)), .missed)
        XCTAssertEqual(harness.store.currentStreak, 1)
        XCTAssertEqual(reviewPrompt(harness), .show)
    }

    /// The ring's day-1 insertion is logged in onboarding on 27 Sep; day 22 is 18 Oct.
    func testARingInsertionLoggedInOnboardingReachesTheReviewPromptAtTheRemoval() throws {
        let harness = try makeHarness(now: Self.afterReminder)
        clearReviewPromptHistory(harness.store)

        harness.commit(pick(.ring, 1, .taken))

        XCTAssertEqual(reviewPrompt(harness), .suppressed(.ineligibleStreak))

        logOnHome(harness, on: "2026-10-18")

        XCTAssertEqual(harness.store.currentStreak, 2)
        XCTAssertEqual(reviewPrompt(harness), .show)
    }
}

private final class DialCompletionRecorder: AnalyticsTracking {
    private(set) var completions: [AnalyticsSource?] = []

    func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource?,
        step: AnalyticsStep?,
        stepIndex: Int?,
        screen: AnalyticsScreen?,
        plan: AnalyticsPlan?,
        result: AnalyticsResult?,
        setting: AnalyticsSetting?,
        acquisitionSource: AcquisitionSource?,
        isPlus: Bool?,
        hasBlockingSelection: Bool?,
        interventionCount: Int?,
        shakeCount: Int?,
        trialWarningDay: Int?,
        trialEndCohort: TrialEndPaywallCohort?,
        titleCustomized: Bool?,
        bodyCustomized: Bool?,
        retryTitleCustomized: Bool?,
        retryBodyCustomized: Bool?,
    ) {
        if event == .todayActionCompleted {
            completions.append(source)
        }
    }
}

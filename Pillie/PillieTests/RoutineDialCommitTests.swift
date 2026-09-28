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

        func commit(_ pick: RoutineDialPick) {
            TodayPillCommit.run(pick, store: store, now: now, defaults: defaults, telemetry: telemetry)
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

    func testBeforeTheReminderHomeStillShowsYesterdaysWindowForAPickWithoutYes() throws {
        let harness = try makeHarness(now: Self.noon)

        harness.commit(pick(.patch, 10, nil))

        XCTAssertEqual(harness.store.dueAction(on: harness.store.today)?.cycleDay, 9)
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

    func testClearDropsTheDialDraftAndTheReportedFlag() throws {
        let harness = try makeHarness(now: Self.afterReminder)
        pick(.ring, 1, .taken).save(to: harness.defaults)
        harness.commit(pick(.ring, 1, .taken))
        XCTAssertTrue(harness.defaults.bool(forKey: TodayPillCommit.reportedStorageKey))

        TodayPillCommit.clear(from: harness.defaults)

        XCTAssertNil(RoutineDialPick.load(from: harness.defaults))
        XCTAssertFalse(harness.defaults.bool(forKey: TodayPillCommit.reportedStorageKey))
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

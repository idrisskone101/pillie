//
//  TodayPillCommitTests.swift
//  PillieTests
//
//  ENG-138: committing the onboarding pill pick with the final reminder time.
//

import XCTest

@testable import Pillie

// The Xcode 27 beta aborts hosted tests when an app-module class deallocates during
// a test, so stores, containers, recorders, and telemetry live for the process.
@MainActor private var retainedForProcessLifetime: [Any] = []

@MainActor
final class TodayPillCommitTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    private struct Harness {
        let store: PillStore
        let recorder: CompletionRecorder
        let defaults: UserDefaults
        let telemetry: ProductAnalyticsTelemetry
        let now: Date

        func commit(_ pick: TodayPillPick) {
            TodayPillCommit.run(pick, store: store, now: now, defaults: defaults, telemetry: telemetry)
        }
    }

    private func makeHarness(now: Date, reminderHour: Int, name: String = #function) throws -> Harness {
        let fixture = try InMemoryStoreFactory.makeStore(now: now)
        fixture.store.reminderHour = reminderHour
        let recorder = CompletionRecorder()
        let suite = "TodayPillCommitTests.\(name)"
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

    private func pick(_ index: Int, _ answer: TodayPillPick.Answer?, _ regimen: PillPack.PillRegimenPreset = .twentyOneSeven) -> TodayPillPick {
        TodayPillPick(regimen: regimen, pillIndex: index, answer: answer)!
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: date))!
    }

    // MARK: Taken

    func testTakenBeforeAnEveningReminderLogsTheTappedPillInTheOpenWindow() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(11, .taken))

        let store = harness.store
        XCTAssertEqual(store.today, day(-1, from: now))
        XCTAssertEqual(store.currentDayIndex + 1, 12)
        XCTAssertTrue(store.isTodayTaken)
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(harness.recorder.completions, [.onboarding])

        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate("2026-09-27", hour: 20, minute: 30))
        store.refreshDayContextIfNeeded()
        XCTAssertEqual(store.currentDayIndex + 1, 13)
        XCTAssertFalse(store.isTodayTaken)
    }

    func testTakenAfterAMorningReminderLogsTodayAndAsksForTheNextPillTomorrow() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 8)

        harness.commit(pick(11, .taken))

        XCTAssertEqual(harness.store.today, day(0, from: now))
        XCTAssertEqual(harness.store.currentDayIndex + 1, 12)
        XCTAssertTrue(harness.store.isTodayTaken)
        XCTAssertEqual(harness.store.currentStreak, 1)
    }

    // MARK: Not yet

    func testNotYetBeforeAnEveningReminderMakesTonightsWindowTheTappedPill() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)
        let store = harness.store

        harness.commit(pick(11, .notYet))

        XCTAssertEqual(store.pack.cycleDayIndex(on: day(0, from: now)) + 1, 12)
        XCTAssertNotEqual(store.statusForDate(day(0, from: now)), .taken)
        XCTAssertEqual(store.statusForDate(day(-1, from: now)), .taken, "the open window is pill 11, already behind the user")
        XCTAssertTrue(harness.recorder.completions.isEmpty)

        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate("2026-09-27", hour: 20, minute: 30))
        store.refreshDayContextIfNeeded()
        XCTAssertEqual(store.currentDayIndex + 1, 12)
        XCTAssertEqual(store.todayDueAction?.cycleDay, 12)
        XCTAssertFalse(store.isTodayTaken)
    }

    func testNotYetAfterAnEveningReminderIsDueNow() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 21, minute: 5)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(11, .notYet))

        XCTAssertEqual(harness.store.currentDayIndex + 1, 12)
        XCTAssertEqual(harness.store.todayDueAction?.cycleDay, 12)
        XCTAssertFalse(harness.store.isTodayTaken)
        XCTAssertEqual(harness.store.currentStreak, 0)
    }

    /// Before today's reminder the live day is yesterday, which precedes pill 1.
    /// Home must show nothing due, and blocking must treat that day as handled.
    func testFirstPillNotYetBeforeTheReminderLeavesNothingDueInTheOpenWindow() throws {
        for regimen in [PillPack.PillRegimenPreset.twentyOneSeven, .everyDay] {
            let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
            let harness = try makeHarness(now: now, reminderHour: 20, name: "firstPill.\(regimen.rawValue)")
            let store = harness.store

            harness.commit(pick(0, .notYet, regimen))

            XCTAssertEqual(store.pack.startDate, day(0, from: now), "\(regimen)")
            XCTAssertNil(store.scheduleSnapshot(for: store.today), "\(regimen)")
            XCTAssertNil(store.todayDueAction, "\(regimen)")
            XCTAssertFalse(store.isTodayTaken, "\(regimen)")
            XCTAssertTrue(store.isTodayHandled, "\(regimen)")
            XCTAssertEqual(store.currentStreak, 0, "\(regimen)")
        }
    }

    // MARK: Pill-free and sugar days

    func testPillFreeDayAnchorsOnTodayWithoutLogging() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(23, nil, .twentyOneOnly))

        XCTAssertEqual(harness.store.pack.pillRegimen, .twentyOneOnly)
        XCTAssertEqual(harness.store.pack.cycleDayIndex(on: day(0, from: now)) + 1, 24)
        XCTAssertTrue(harness.recorder.completions.isEmpty)
    }

    func testTakenSugarPillAnchorsOnTheOpenWindowWithoutLogging() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(23, .taken))

        XCTAssertEqual(harness.store.currentDayIndex + 1, 24)
        XCTAssertTrue(harness.recorder.completions.isEmpty)
    }

    // MARK: Idempotency

    func testRepeatedCommitsConvergeAndReportTheDoseOnce() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 8)
        let store = harness.store
        let today = day(0, from: now)

        harness.commit(pick(11, .taken))
        harness.commit(pick(11, .taken))
        XCTAssertEqual(store.currentDayIndex + 1, 12)
        XCTAssertEqual(store.pack.days.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count, 1)
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(harness.recorder.completions, [.onboarding])

        harness.commit(pick(0, .notYet))
        XCTAssertEqual(store.currentDayIndex + 1, 1)
        XCTAssertNotEqual(store.statusForDate(today), .taken)

        harness.commit(pick(11, .taken))
        XCTAssertTrue(store.isTodayTaken)
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(harness.recorder.completions, [.onboarding])
    }
}

/// Records `today_action_completed` sources.
private final class CompletionRecorder: AnalyticsTracking {
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

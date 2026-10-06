//
//  TodayPillCommitTests.swift
//  PillieTests
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

        func commit(_ pick: TodayPillPick, pickedAt: Date? = nil) {
            TodayPillCommit.run(
                OnboardingDraft(pick: pick, pickedAt: pickedAt ?? now),
                store: store,
                now: now,
                defaults: defaults,
                telemetry: telemetry
            )
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
        TodayPillPick(pack: PackChoice(preset: regimen), dayIndex: index, answer: answer)!
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: date))!
    }

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

    func testCommitRecordsTheInstallOnceAndKeepsTheFirstDate() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(11, .notYet))
        XCTAssertEqual(FirstReminderInstall.date(in: harness.defaults), now)

        let later = InMemoryStoreFactory.localDate("2026-09-28", hour: 9, minute: 0)
        FirstReminderInstall.record(at: later, in: harness.defaults)
        XCTAssertEqual(FirstReminderInstall.date(in: harness.defaults), now)

        TodayPillCommit.clear(from: harness.defaults)
        XCTAssertEqual(FirstReminderInstall.date(in: harness.defaults), now, "Today reads it after onboarding clears its keys")
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

    func testFirstPillNotYetBeforeTheReminderStartsTheFirstLiveDayNow() throws {
        for regimen in [PillPack.PillRegimenPreset.twentyOneSeven, .everyDay] {
            let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
            let harness = try makeHarness(now: now, reminderHour: 20, name: "firstPill.\(regimen.rawValue)")
            let store = harness.store

            harness.commit(pick(0, .notYet, regimen))

            XCTAssertEqual(store.pack.startDate, day(0, from: now), "\(regimen)")
            XCTAssertEqual(store.today, day(0, from: now), "\(regimen)")
            XCTAssertNotNil(store.scheduleSnapshot(for: store.today), "\(regimen)")
            XCTAssertEqual(store.todayDueAction?.cycleDay, 1, "\(regimen)")
            XCTAssertEqual(store.currentDayIndex + 1, 1, "\(regimen)")
            XCTAssertFalse(store.isTodayTaken, "\(regimen)")
            XCTAssertFalse(store.isTodayHandled, "\(regimen)")
            XCTAssertEqual(store.currentStreak, 0, "\(regimen)")
        }
    }

    func testPillFreeDayAnchorsOnTodayWithoutLogging() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(23, nil, .twentyOneOnly))

        XCTAssertEqual(harness.store.pack.pillRegimen, .twentyOneOnly)
        XCTAssertEqual(harness.store.pack.cycleDayIndex(on: day(0, from: now)) + 1, 24)
        XCTAssertTrue(harness.recorder.completions.isEmpty)
    }

    func testTakenSugarPillLogsTheDoseWithoutStartingAStreak() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(23, .taken))

        XCTAssertEqual(harness.store.currentDayIndex + 1, 24)
        XCTAssertTrue(harness.store.isTodayTaken)
        XCTAssertEqual(harness.store.currentStreak, 0)
        XCTAssertEqual(harness.recorder.completions, [.onboarding])
    }

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

    func testASecondPassWithANewReminderTimeMovesTheAnchorButReportsOnce() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)
        let store = harness.store

        harness.commit(pick(11, .taken))
        XCTAssertEqual(store.today, day(-1, from: now))

        store.reminderHour = 9
        harness.commit(pick(11, .taken))

        XCTAssertEqual(store.today, day(0, from: now))
        XCTAssertEqual(store.currentDayIndex + 1, 12)
        XCTAssertTrue(store.isTodayTaken)
        XCTAssertEqual(harness.recorder.completions, [.onboarding])
    }

    func testEveryPackSheetPresetSavesIntoTheSchedule() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let expected: [(PillPack.PillRegimenPreset, PackRegimen)] = [
            (.twentyOneSeven, PackRegimen(activeDays: 21, breakDays: 7)),
            (.twentyOneOnly, PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills)),
            (.twentyFourFour, PackRegimen(activeDays: 24, breakDays: 4)),
            (.twentySixTwo, PackRegimen(activeDays: 26, breakDays: 2)),
            (.everyDay, PackRegimen(activeDays: 28, breakDays: 0)),
            (.twentyOneFour, PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills)),
        ]

        for (preset, regimen) in expected {
            let harness = try makeHarness(now: now, reminderHour: 20, name: "\(#function).\(preset.rawValue)")

            harness.commit(pick(0, .notYet, preset))

            XCTAssertEqual(harness.store.pack.pillRegimen, preset, "\(preset)")
            XCTAssertEqual(harness.store.pack.regimen, regimen, "\(preset)")
        }
    }

    func testATakenPickFromYesterdayCommitsTheNextPillUnlogged() throws {
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let now = InMemoryStoreFactory.localDate("2026-09-28", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 8)

        harness.commit(pick(11, .taken), pickedAt: pickedAt)

        let store = harness.store
        XCTAssertEqual(store.currentDayIndex + 1, 13)
        XCTAssertFalse(store.isTodayTaken)
        XCTAssertEqual(store.statusForDate(day(-1, from: now)), .taken)
        XCTAssertTrue(harness.recorder.completions.isEmpty)
    }

    func testANotYetPickFromYesterdayMakesTonightTheNextPill() throws {
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let now = InMemoryStoreFactory.localDate("2026-09-28", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(11, .notYet), pickedAt: pickedAt)

        let store = harness.store
        XCTAssertEqual(store.pack.cycleDayIndex(on: day(0, from: now)) + 1, 13)
        XCTAssertEqual(store.statusForDate(day(-1, from: now)), .taken)
        XCTAssertTrue(harness.recorder.completions.isEmpty)
    }

    func testCrossingTheReminderBeforeContinueMovesToTheNextPill() throws {
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-27", hour: 19, minute: 50)
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 20, minute: 10)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(11, .taken), pickedAt: pickedAt)

        let store = harness.store
        XCTAssertEqual(store.currentDayIndex + 1, 13)
        XCTAssertFalse(store.isTodayTaken)
        XCTAssertTrue(harness.recorder.completions.isEmpty)
    }

    func testARollPastThePackEndStartsTheNextPack() throws {
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let now = InMemoryStoreFactory.localDate("2026-09-28", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 8)

        harness.commit(pick(27, .taken), pickedAt: pickedAt)

        XCTAssertEqual(harness.store.currentDayIndex + 1, 1)
    }

    func testNotYetAfterTheReminderReportsAnEveningAnswerOnce() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 21)
        let harness = try makeHarness(now: now, reminderHour: 8)

        harness.commit(pick(0, .notYet))
        harness.commit(pick(0, .notYet))

        XCTAssertEqual(harness.recorder.answers, ["onboarding_today_answer not_yet after_reminder=true"])
    }

    func testTakenBeforeTheReminderReportsAMorningAnswer() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(11, .taken))

        XCTAssertEqual(harness.recorder.answers, ["onboarding_today_answer taken after_reminder=false"])
    }

    func testAPillFreeDayReportsNoAnswer() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)

        harness.commit(pick(23, nil, .twentyOneOnly))

        XCTAssertEqual(harness.recorder.answers, [])
    }

    func testCustomPackSavesItsOwnRegimenIntoTheSchedule() throws {
        let now = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let harness = try makeHarness(now: now, reminderHour: 20)
        let custom = PackChoice(PackRegimen(activeDays: 88, breakDays: 3))

        harness.commit(try XCTUnwrap(TodayPillPick(pack: custom, dayIndex: 60, answer: .notYet)))

        XCTAssertEqual(harness.store.pack.pillRegimen, .custom)
        XCTAssertEqual(harness.store.pack.regimen, PackRegimen(activeDays: 88, breakDays: 3))
        XCTAssertEqual(harness.store.pack.cycleDayIndex(on: now), 60)
    }
}

private final class CompletionRecorder: AnalyticsTracking {
    private(set) var completions: [AnalyticsSource?] = []
    private(set) var answers: [String] = []

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

    func track(_ event: AnalyticsEvent, todayAnswer: AnalyticsTodayAnswer, afterReminder: Bool, isPlus: Bool?) {
        answers.append("\(event.rawValue) \(todayAnswer.rawValue) after_reminder=\(afterReminder)")
    }
}

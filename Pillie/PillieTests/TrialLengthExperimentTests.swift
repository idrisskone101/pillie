//
//  TrialLengthExperimentTests.swift
//  PillieTests
//
//  trial_length_v1: which installs get a 7-day Reverse Trial, how the clock
//  counts it, which copy it reads, and where its notices land.
//

import Foundation
import Testing

@testable import Pillie

@MainActor
struct TrialLengthAssignmentTests {
    /// A PostHog flag value, kept `Sendable` for test arguments.
    enum FlagValue: Sendable {
        case missing
        case bool(Bool)
        case string(String)
        case int(Int)

        var raw: Any? {
            switch self {
            case .missing: nil
            case .bool(let value): value
            case .string(let value): value
            case .int(let value): value
            }
        }
    }

    @Test(arguments: [
        ("seven_days", TrialLength.sevenDays),
        ("control", TrialLength.fourteenDays),
    ])
    func `A calendar-day install takes a known variant from the flag`(variant: String, length: TrialLength) {
        let assignment = TrialLengthExperiment.assignment(dayRule: .calendarDays, flagValue: variant)
        #expect(assignment == TrialLengthAssignment(length: length, isFromFlag: true))
    }

    @Test(arguments: [FlagValue.missing, .bool(false), .bool(true), .string("fourteen_days"), .int(7)])
    func `A calendar-day install without a known variant stays at 14 days outside the test`(flagValue: FlagValue) {
        let assignment = TrialLengthExperiment.assignment(dayRule: .calendarDays, flagValue: flagValue.raw)
        #expect(assignment == TrialLengthAssignment(length: .fourteenDays, isFromFlag: false))
    }

    @Test(arguments: [FlagValue.missing, .bool(false), .string("seven_days"), .string("control")])
    func `An active-day install never enrolls`(flagValue: FlagValue) {
        let assignment = TrialLengthExperiment.assignment(dayRule: .activeDays, flagValue: flagValue.raw)
        #expect(assignment == TrialLengthAssignment(length: .fourteenDays, isFromFlag: false))
    }

    @Test func `Each length counts its full days`() {
        #expect(TrialLength.fourteenDays.fullDays == 14)
        #expect(TrialLength.sevenDays.fullDays == 7)
    }
}

@MainActor
struct TrialLengthCopyKeyTests {
    @Test(arguments: [
        (TrialDayRule.calendarDays, TrialLength.fourteenDays, "trial.end.kicker"),
        (.calendarDays, .sevenDays, "trial.end.kicker.seven_days"),
        (.activeDays, .fourteenDays, "trial.end.kicker.active_days"),
        (.activeDays, .sevenDays, "trial.end.kicker.active_days"),
    ])
    func `The key follows the rule, then the length`(rule: TrialDayRule, length: TrialLength, key: String) {
        #expect(TrialLength.copyKey("trial.end.kicker", rule: rule, length: length) == key)
    }

    @Test(arguments: [
        ("en", "trial.granted.badge", "7 days free · no card"),
        ("en", "trial.end.legacy.record", "Your 7-day record"),
        ("en", "trial.end.hard.blocker", "For 7 days you had follow-up reminders and app blocking. Keep Plus to hold on to both."),
        ("ar", "trial.granted.badge", "7 أيام مجانًا · بدون بطاقة"),
        ("de", "trial.end.kicker", "Deine 7 Tage"),
    ])
    func `A 7-day install reads 7 days`(language: String, key: String, expected: String) {
        let copyKey = TrialLength.copyKey(key, rule: .calendarDays, length: .sevenDays)
        let text = PillieLocalization.string(copyKey, table: "Commerce", locale: Locale(identifier: language))
        #expect(text == expected)
    }

    @Test func `A 7-day during-trial board names day 7`() {
        let text = PillieLocalization.formatted(
            TrialLength.copyKey("paywall.board.during_trial.subtitle", rule: .calendarDays, length: .sevenDays),
            table: "Commerce",
            locale: Locale(identifier: "en"),
            arguments: Int64(3)
        )
        #expect(text == "You have 3 days left. Pick a plan now and nothing turns off on day 7.")
    }

    @Test func `The timeline labels name day 5 and day 7`() {
        let english = Locale(identifier: "en")
        #expect(PillieLocalization.string(
            TrialLength.sevenDays.variantKey("trial.granted.warning.label"), table: "Commerce", locale: english
        ) == "Day 5")
        #expect(PillieLocalization.string(
            TrialLength.sevenDays.variantKey("trial.granted.choice.label"), table: "Commerce", locale: english
        ) == "Day 7")
        #expect(TrialLength.fourteenDays.variantKey("trial.granted.choice.label") == "trial.granted.choice.label")
    }
}

@MainActor
struct TrialLengthStoreTests {
    @Test func `The in-memory store keeps the length until the grant is cleared`() {
        let store = InMemoryTrialGrantStore()
        #expect(store.loadTrialLength() == nil)

        store.saveGrantDate(Date(timeIntervalSince1970: 1_780_000_000))
        store.saveTrialLength(.sevenDays)
        #expect(store.loadTrialLength() == .sevenDays)

        store.clearGrantDate()
        #expect(store.loadTrialLength() == nil)
        #expect(store.loadGrantDate() == nil)
    }
}

@MainActor
struct SevenDayClockTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    @Test func `A July 1 grant covers July 2 through 8 and ends at midnight starting July 9`() {
        let clock = ReverseTrialClock(grantDate: date(1, 14, 30), fullDays: 7)

        #expect(clock.expiryMoment(calendar: calendar) == date(9, 0))
        #expect(clock.isActive(calendar: calendar, now: date(8, 23, 59)))
        #expect(!clock.isActive(calendar: calendar, now: date(9, 0)))
        #expect(clock.endsTonight(calendar: calendar, now: date(8, 9)))
        #expect(!clock.endsTonight(calendar: calendar, now: date(7, 9)))
    }

    @Test func `The displayed count never reads above 7`() {
        let clock = ReverseTrialClock(grantDate: date(1, 14, 30), fullDays: 7)

        #expect(clock.daysRemaining(calendar: calendar, now: date(1, 14, 30)) == 8)
        #expect(clock.displayedDaysRemaining(calendar: calendar, now: date(1, 14, 30)) == 7)
        #expect(clock.displayedDaysRemaining(calendar: calendar, now: date(2, 9)) == 7)
        #expect(clock.displayedDaysRemaining(calendar: calendar, now: date(5, 9)) == 4)
        #expect(clock.displayedDaysRemaining(calendar: calendar, now: date(8, 9)) == 1)
        #expect(clock.displayedDaysRemaining(calendar: calendar, now: date(9, 9)) == 0)
    }

    @Test func `The status sheet fills a 7-day bar`() throws {
        let state = PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: date(1, 14, 30),
            trialLength: .sevenDays
        )
        let presentation = try #require(TrialStatusPresentation.make(
            state: state,
            calendar: calendar,
            now: date(4, 9),
            locale: Locale(identifier: "en")
        ))

        #expect(presentation.displayedDaysRemaining == 5)
        #expect(presentation.currentDay == 3)
        #expect(presentation.sheetContent.progress.totalDays == 7)
        #expect(presentation.sheetContent.progress.filledDays == 3)
    }
}

/// The notices and win-backs count back from the clock's expiry, so a 7-day
/// trial moves them without any change of its own.
@MainActor
@Suite(.serialized)
struct SevenDayTrialNoticeTests {
    private let planner = ReminderSchedulePlanner()

    @Test func `Warnings land 5 and 2 days before a 7-day expiry`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let grant = InMemoryStoreFactory.localDate("2026-07-01", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: grant, startDate: grant)

        let warnings = plan(store: fixture.store, now: grant, grant: grant, terms: .legacy)
            .compactMap { intent -> ReminderSchedulePlanner.TrialExpiryWarningIntent? in
                if case .trialExpiryWarning(let warning) = intent { return warning }
                return nil
            }
            .sorted { $0.day < $1.day }

        #expect(warnings.map(\.day) == [10, 13, 15])
        #expect(warnings.map(\.fireDate) == [
            InMemoryStoreFactory.localDate("2026-07-04", hour: 20),
            InMemoryStoreFactory.localDate("2026-07-07", hour: 20),
            InMemoryStoreFactory.localDate("2026-07-09", hour: 10),
        ])
    }

    @Test func `Win-backs start on the 7-day expiry day`() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let grant = InMemoryStoreFactory.localDate("2026-07-01", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: grant, startDate: grant)

        let winbacks = plan(
            store: fixture.store,
            now: grant,
            grant: grant,
            terms: .hardPaywall,
            winback: WinbackContext(daysLogged: 5, lastAppOpen: nil, slot2Arm: .control)
        )
        .compactMap { intent -> WinbackIntent? in
            if case .winback(let winback) = intent { return winback }
            return nil
        }

        #expect(winbacks.map(\.slot) == [.expiryDay, .dayAfter, .lastNote])
        #expect(winbacks.map(\.fireDate) == [
            InMemoryStoreFactory.localDate("2026-07-09", hour: 9),
            InMemoryStoreFactory.localDate("2026-07-10", hour: 8),
            InMemoryStoreFactory.localDate("2026-07-16", hour: 9),
        ])
    }

    private func plan(
        store: PillStore,
        now: Date,
        grant: Date,
        terms: TrialEndAccessTerms,
        winback: WinbackContext? = nil
    ) -> [ReminderSchedulePlanner.Intent] {
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )
        return planner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                scheduleDay: store.today,
                pack: store.pack,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                autoReminderIntervalMinutes: store.autoReminderIntervalMinutes,
                autoReminderRetryLimit: store.autoReminderRetryLimit,
                refillReminderThresholdDays: store.refillReminderThresholdDays,
                patchRestockReminderThresholdPatches: store.patchRestockReminderThresholdPatches,
                candidateDueActions: candidateDueActions,
                statusByEpochDay: store.statusesByEpochDay(for: candidateDueActions.map(\.date)),
                snoozeOverride: nil,
                smartRemindersEnabled: true,
                cycleTransitionEnabled: true,
                trialGrantDate: grant,
                hasEntitlement: false,
                trialEndTerms: terms,
                winback: winback,
                servedBaseFireDateByDueDayEpoch: [:],
                calendar: .current,
                trialLength: .sevenDays
            )
        )
    }
}

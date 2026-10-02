//
//  SugarPillDoseTests.swift
//  PillieTests
//

#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct SugarPillScheduleTests {
    private static var retainedPacks: [PillPack] = []

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!)!
    }

    private func pack(_ regimen: PillPack.PillRegimenPreset) -> PillPack {
        let pack = PillPack(method: .pill, pillRegimen: regimen, startDate: day(0), packNumber: 1)
        Self.retainedPacks.append(pack)
        return pack
    }

    private func type(onPackDay number: Int, _ pack: PillPack) -> PillDay.ActionType? {
        DoseScheduleEngine.dueAction(on: day(number - 1), pack: pack, calendar: calendar)?.type
    }

    @Test func pillBreakDayIsSugarOnlyWhenThePackHasSugarPills() {
        let twentyOneSeven = pack(.twentyOneSeven)
        let twentyOneOnly = pack(.twentyOneOnly)
        let twentyFourFour = pack(.twentyFourFour)

        #expect(type(onPackDay: 22, twentyOneSeven) == .pillSugar)
        #expect(type(onPackDay: 28, twentyOneSeven) == .pillSugar)
        #expect(type(onPackDay: 22, twentyOneOnly) == .pillBreak)
        #expect(type(onPackDay: 25, twentyFourFour) == .pillSugar)
        #expect(type(onPackDay: 24, twentyFourFour) == .pillActive)
        #expect((1...21).map { type(onPackDay: $0, twentyOneSeven) } == Array(repeating: .pillActive, count: 21))
    }

    @Test func dayBeforeThePackStartsHasNothingDue() {
        let next = DoseScheduleEngine.nextDueActions(from: day(-1), limit: 1, pack: pack(.twentyOneSeven), calendar: calendar)
        #expect(next.map(\.date) == [day(0)])
        #expect(next.map(\.type) == [.pillActive])
    }

    @Test func predicatesSeparateLoggingFromAdherence() {
        let rows: [PillDay.ActionType] = [.pillActive, .pillSugar, .pillBreak]
        let table = rows.map { [$0.requiresUserAction, $0.isBreakType, $0.enforcesAdherence] }
        #expect(table == [
            [true, false, true],
            [true, true, false],
            [false, true, false]
        ])
    }

    @Test func sugarPillKeepsThePillCopy() throws {
        let action = try #require(DoseScheduleEngine.dueAction(on: day(21), pack: pack(.twentyOneSeven), calendar: calendar))
        #expect(DueActionCopy.key(for: action) == "today.action.take_pill")
        #expect(action.badgeLabel == "PILL")
        #expect(action.localizedReminderBody(locale: Locale(identifier: "en")) == "Hey, quick check-in. Log your pill when you're done")
    }

    @Test func sugarDayGetsDueRemindersAndNoTransitionNotice() {
        let now = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day(20))!
        func plan(_ regimen: PillPack.PillRegimenPreset) -> (dueDays: [Int], notices: Int) {
            let pack = pack(regimen)
            let intents = ReminderSchedulePlanner().planReminders(
                ReminderSchedulePlanner.Input(
                    now: now,
                    scheduleDay: calendar.startOfDay(for: now),
                    pack: pack,
                    reminderHour: 8,
                    reminderMinute: 0,
                    autoReminderIntervalMinutes: 10,
                    autoReminderRetryLimit: 0,
                    refillReminderThresholdDays: 5,
                    patchRestockReminderThresholdPatches: 1,
                    candidateDueActions: DoseScheduleEngine.nextDueActions(
                        from: now,
                        limit: ReminderSchedulePlanner.dueScanLimit,
                        pack: pack,
                        calendar: calendar
                    ),
                    statusByEpochDay: [:],
                    snoozeOverride: nil,
                    smartRemindersEnabled: false,
                    cycleTransitionEnabled: true,
                    trialGrantDate: nil,
                    hasEntitlement: false,
                    servedBaseFireDateByDueDayEpoch: [:],
                    calendar: calendar
                )
            )
            var dueDays: [Int] = []
            var notices = 0
            for intent in intents {
                switch intent {
                case .due(let due):
                    dueDays.append(due.action.cycleDay)
                case .cycleTransition:
                    notices += 1
                default:
                    break
                }
            }
            return (Array(dueDays.prefix(4)), notices)
        }

        let sugar = plan(.twentyOneSeven)
        #expect(sugar.dueDays == [21, 22, 23, 24])
        #expect(sugar.notices == 0)

        let pillFree = plan(.twentyOneOnly)
        #expect(pillFree.dueDays == [21, 1, 2, 3])
        #expect(pillFree.notices == 1)
    }
}

@MainActor
struct SugarPillStoreTests {
    private static var retained: [Any] = []

    private func store(regimen: PillPack.PillRegimenPreset, now: Date) throws -> PillStore {
        let startDate = InMemoryStoreFactory.localDate("2026-05-01", hour: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, regimen: regimen, startDate: startDate)
        Self.retained.append(fixture)
        return fixture.store
    }

    @Test func sugarDayIsDueButNeverBlocks() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(regimen: .twentyOneSeven, now: InMemoryStoreFactory.localDate("2026-05-23", hour: 12))

        #expect(store.todayDueAction?.type == .pillSugar)
        #expect(store.statusForDate(store.today) == .upcoming)
        #expect(store.isTodayTaken == false)
        #expect(store.isTodayHandled == true)
        #expect(store.isTodayNothingDue == false)
        #expect(store.blockingScheduleMirror.actionDayIndices.sorted() == Array(0..<21))
    }

    @Test func pillFreeBreakDayStaysNothingDue() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(regimen: .twentyOneOnly, now: InMemoryStoreFactory.localDate("2026-05-23", hour: 12))

        #expect(store.todayDueAction == nil)
        #expect(store.statusForDate(store.today) == .breakDay)
        #expect(store.isTodayHandled == true)
        #expect(store.isTodayNothingDue == true)
    }

    @Test func loggedSugarPillSurvivesRelaunchAndUndoes() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let now = InMemoryStoreFactory.localDate("2026-05-23", hour: 12)
        let startDate = InMemoryStoreFactory.localDate("2026-05-01", hour: 0)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, regimen: .twentyOneSeven, startDate: startDate)
        Self.retained.append(fixture)
        let store = fixture.store

        store.markTodayAsTaken()
        #expect(store.isTodayTaken == true)

        let relaunched = PillStore(modelContext: fixture.context)
        Self.retained.append(relaunched)
        #expect(relaunched.isTodayTaken == true)
        #expect(fixture.pack.days.map(\.status) == [.taken])

        relaunched.unmarkTodayAsTaken()
        #expect(relaunched.isTodayTaken == false)
        #expect(relaunched.todayDueAction?.type == .pillSugar)
        #expect(relaunched.statusForDate(relaunched.today) == .upcoming)
    }

    @Test func sugarPillsNeitherExtendNorBreakTheStreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(regimen: .twentyOneSeven, now: InMemoryStoreFactory.localDate("2026-05-24", hour: 12))
        for dayOfMonth in 19...21 {
            store.markActionAsTaken(on: InMemoryStoreFactory.localDate("2026-05-\(dayOfMonth)", hour: 12))
        }
        let sugarDay = InMemoryStoreFactory.localDate("2026-05-22", hour: 12)
        let skippedSugarDay = InMemoryStoreFactory.localDate("2026-05-23", hour: 12)
        let streakBefore = store.currentStreak

        store.markActionAsTaken(on: sugarDay)
        store.markTodayAsTaken()

        #expect(streakBefore == 3)
        #expect(store.currentStreak == 3)
        #expect(store.statusForDate(sugarDay) == .taken)
        #expect(store.statusForDate(skippedSugarDay) == .breakDay)
        #expect(store.monthAdherence(for: sugarDay).due == 21)
    }

    @Test func historyReadsTodaysSugarPillAsDueUntilItsWindowCloses() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(regimen: .twentyFourFour, now: InMemoryStoreFactory.localDate("2026-05-24", hour: 12))
        let hormoneDay = InMemoryStoreFactory.localDate("2026-05-24", hour: 0)
        let sugarDay = InMemoryStoreFactory.localDate("2026-05-25", hour: 0)
        func history(_ date: Date, _ relation: CalendarDayRelation) -> (PillDay.Status?, HistoryPresentation.DayStatus) {
            let snapshot = store.scheduleSnapshot(for: date)
            let presentation = CalendarDayPresentation.resolve(snapshot: snapshot, fallbackMethod: .pill, relation: relation)
            return (snapshot?.status, presentation.historyStatus)
        }

        let hormoneToday = history(hormoneDay, .today)
        #expect(hormoneToday.0 == .upcoming)
        #expect(hormoneToday.1 == .unlogged)

        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate("2026-05-25", hour: 12))
        store.refreshDayContextIfNeeded()
        #expect(store.todayDueAction?.type == .pillSugar)
        let sugarToday = history(sugarDay, .today)
        #expect(sugarToday.0 == .upcoming)
        #expect(sugarToday.1 == .unlogged)

        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate("2026-05-26", hour: 12))
        store.refreshDayContextIfNeeded()
        let sugarClosed = history(sugarDay, .past)
        #expect(sugarClosed.0 == .breakDay)
        #expect(sugarClosed.1 == .breakDay)

        store.markTodayAsTaken()
        let sugarLogged = history(InMemoryStoreFactory.localDate("2026-05-26", hour: 0), .today)
        #expect(sugarLogged.0 == .taken)
        #expect(sugarLogged.1 == .completed)
    }

    @Test func historyReadsAPillFreeDayAsABreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(regimen: .twentyOneOnly, now: InMemoryStoreFactory.localDate("2026-05-23", hour: 12))
        let snapshot = store.scheduleSnapshot(for: store.today)
        let presentation = CalendarDayPresentation.resolve(snapshot: snapshot, fallbackMethod: .pill, relation: .today)

        #expect(snapshot?.status == .breakDay)
        #expect(presentation.historyStatus == .breakDay)
    }

    @Test func sugarDaysDoNotConsumeTrialDays() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(regimen: .twentyOneSeven, now: InMemoryStoreFactory.localDate("2026-05-23", hour: 12))

        #expect(ActiveDaySchedule(pack: store.pack).hormoneActiveIndices == Set(0..<21))
    }
}
#endif

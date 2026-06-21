//
//  ReminderSchedulePlannerTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class ReminderSchedulePlannerTests: XCTestCase {
    private let planner = ReminderSchedulePlanner()

    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testSchedulesCatchupWhenConfiguredTimeHasPassedForToday() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 10)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.reminderHour = 8
        fixture.store.reminderMinute = 0

        let todayEpoch = epochDay(for: now)
        let todayBase = try XCTUnwrap(dueIntents(for: fixture.store, now: now).first {
            $0.dueDayEpoch == todayEpoch && $0.kind == .base
        })

        XCTAssertGreaterThan(todayBase.fireDate, now)
        XCTAssertLessThanOrEqual(todayBase.fireDate.timeIntervalSince(now), 60)
    }

    func testSkipsTakenDueActionsUsingStatusMap() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let intents = dueIntents(
            for: fixture.store,
            now: now,
            statusOverrides: [todayEpoch: .taken]
        )

        XCTAssertFalse(intents.contains { $0.dueDayEpoch == todayEpoch })
        XCTAssertTrue(intents.contains { $0.kind == .base })
    }

    func testCapsPlanAtPendingLimitAndReservesSupplySlot() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            regimen: .threeSixtyFiveZero,
            startDate: now
        )

        let intents = plan(
            for: fixture.store,
            now: now,
            autoReminderIntervalMinutes: 5,
            autoReminderRetryLimit: 100
        )

        XCTAssertEqual(intents.count, ReminderSchedulePlanner.maxPendingReminders)
        XCTAssertEqual(intents.filter(\.isSupply).count, 1)
        XCTAssertEqual(intents.filter(\.isDue).count, ReminderSchedulePlanner.maxPendingReminders - 1)
    }

    func testKeepsPrimaryReminderWhenRetryLimitIsZero() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 0)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
    }

    func testCapsSameDayRetriesByRetryLimit() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(for: fixture.store, now: now, autoReminderRetryLimit: 3)
            .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 3)
    }

    func testTreatsSnoozeAsSeparateFromAutomaticRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 1,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            )
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testFreeUserGetsSingleDueReminderWithNoRetries() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            smartRemindersEnabled: false
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
    }

    func testFreeUserSnoozeOverrideIsIgnored() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            ),
            smartRemindersEnabled: false
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 0)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 0)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 1)
    }

    func testPlusUserRetainsRetriesAndSnooze() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let todayEpoch = epochDay(for: now)
        let snoozeFireDate = now.addingTimeInterval(10 * 60)

        let todayIntents = dueIntents(
            for: fixture.store,
            now: now,
            autoReminderRetryLimit: 3,
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                dueDayEpoch: todayEpoch,
                firstFireDate: snoozeFireDate
            ),
            smartRemindersEnabled: true
        )
        .filter { $0.dueDayEpoch == todayEpoch }

        XCTAssertEqual(todayIntents.filter { $0.kind == .snooze }.count, 1)
        XCTAssertEqual(todayIntents.filter { $0.kind == .retry }.count, 3)
        XCTAssertEqual(todayIntents.filter { $0.kind == .base }.count, 0)
    }

    func testFreeUserStillReceivesSupplyReminders() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)

        let supply = plan(for: pillFixture.store, now: now, smartRemindersEnabled: false)
            .compactMap { intent -> ReminderSchedulePlanner.SupplyReminderIntent? in
                if case .supply(let supply) = intent { return supply }
                return nil
            }

        XCTAssertEqual(supply.map(\.method), [.pill])
    }

    func testBuildsPillAndPatchSupplyRemindersButNotRing() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill, startDate: now)
        let patchFixture = try InMemoryStoreFactory.makeStore(now: now, method: .patch, startDate: now)
        let ringFixture = try InMemoryStoreFactory.makeStore(
            now: now,
            method: .ring,
            startDate: now,
            ringInsertionDate: now
        )

        let pillSupply = supplyIntents(for: pillFixture.store, now: now)
        let patchSupply = supplyIntents(for: patchFixture.store, now: now)
        let ringSupply = supplyIntents(for: ringFixture.store, now: now)

        XCTAssertEqual(pillSupply.map(\.method), [.pill])
        XCTAssertEqual(patchSupply.map(\.method), [.patch])
        XCTAssertTrue(ringSupply.isEmpty)
    }

    private func plan(
        for store: PillStore,
        now: Date,
        autoReminderIntervalMinutes: Int? = nil,
        autoReminderRetryLimit: Int? = nil,
        statusOverrides: [Int: PillDay.Status] = [:],
        snoozeOverride: ReminderSchedulePlanner.SnoozeOverride? = nil,
        smartRemindersEnabled: Bool = true
    ) -> [ReminderSchedulePlanner.Intent] {
        let calendar = Calendar.current
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )
        var statusByEpochDay = store.statusesByEpochDay(for: candidateDueActions.map(\.date))
        statusOverrides.forEach { statusByEpochDay[$0.key] = $0.value }

        return planner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                pack: store.pack,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                autoReminderIntervalMinutes: autoReminderIntervalMinutes ?? store.autoReminderIntervalMinutes,
                autoReminderRetryLimit: autoReminderRetryLimit ?? store.autoReminderRetryLimit,
                refillReminderThresholdDays: store.refillReminderThresholdDays,
                patchRestockReminderThresholdPatches: store.patchRestockReminderThresholdPatches,
                candidateDueActions: candidateDueActions,
                statusByEpochDay: statusByEpochDay,
                snoozeOverride: snoozeOverride,
                smartRemindersEnabled: smartRemindersEnabled,
                calendar: calendar
            )
        )
    }

    private func dueIntents(
        for store: PillStore,
        now: Date,
        autoReminderRetryLimit: Int? = nil,
        statusOverrides: [Int: PillDay.Status] = [:],
        snoozeOverride: ReminderSchedulePlanner.SnoozeOverride? = nil,
        smartRemindersEnabled: Bool = true
    ) -> [ReminderSchedulePlanner.DueReminderIntent] {
        plan(
            for: store,
            now: now,
            autoReminderRetryLimit: autoReminderRetryLimit,
            statusOverrides: statusOverrides,
            snoozeOverride: snoozeOverride,
            smartRemindersEnabled: smartRemindersEnabled
        )
        .compactMap { intent in
            if case .due(let due) = intent { return due }
            return nil
        }
    }

    private func supplyIntents(
        for store: PillStore,
        now: Date
    ) -> [ReminderSchedulePlanner.SupplyReminderIntent] {
        plan(for: store, now: now).compactMap { intent in
            if case .supply(let supply) = intent { return supply }
            return nil
        }
    }

    private func epochDay(for date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
    }
}

private extension ReminderSchedulePlanner.Intent {
    var isDue: Bool {
        if case .due = self { return true }
        return false
    }

    var isSupply: Bool {
        if case .supply = self { return true }
        return false
    }
}

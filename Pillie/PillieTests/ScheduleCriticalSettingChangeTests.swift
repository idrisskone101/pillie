//
//  ScheduleCriticalSettingChangeTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class ScheduleCriticalSettingChangeTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testOnboardingReminderTimeSaveMutatesDueActionReminderTime() throws {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-06-03")
        )

        ScheduleCriticalSettingChange.saveOnboardingReminderTime(
            store: fixture.store,
            hour: 21,
            minute: 30
        )

        XCTAssertEqual(fixture.store.reminderHour, 21)
        XCTAssertEqual(fixture.store.reminderMinute, 30)
    }

    func testSettingsReminderTimeSaveMutatesDueActionReminderTime() throws {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-06-03")
        )

        ScheduleCriticalSettingChange.saveSettingsReminderTime(
            store: fixture.store,
            hour: 7,
            minute: 15
        )

        XCTAssertEqual(fixture.store.reminderHour, 7)
        XCTAssertEqual(fixture.store.reminderMinute, 15)
    }

    func testSettingsAutoReminderIntervalSaveMutatesRetryCadence() throws {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-06-03")
        )

        ScheduleCriticalSettingChange.saveSettingsAutoReminderInterval(
            store: fixture.store,
            intervalMinutes: 30
        )

        XCTAssertEqual(fixture.store.autoReminderIntervalMinutes, 30)
    }

    func testSettingsAutoReminderRetryLimitSaveMutatesRetryLimit() throws {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-06-03")
        )

        ScheduleCriticalSettingChange.saveSettingsAutoReminderRetryLimit(
            store: fixture.store,
            retryLimit: 5
        )

        XCTAssertEqual(fixture.store.autoReminderRetryLimit, 5)
    }

    func testSettingsSupplyReminderSaveUsesMethodSpecificThreshold() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-06-03")
        let pillFixture = try InMemoryStoreFactory.makeStore(now: now, method: .pill)
        let patchFixture = try InMemoryStoreFactory.makeStore(now: now, method: .patch)

        ScheduleCriticalSettingChange.saveSettingsSupplyReminderThreshold(
            store: pillFixture.store,
            threshold: 7
        )
        ScheduleCriticalSettingChange.saveSettingsSupplyReminderThreshold(
            store: patchFixture.store,
            threshold: 2
        )

        XCTAssertEqual(pillFixture.store.refillReminderThresholdDays, 7)
        XCTAssertEqual(patchFixture.store.patchRestockReminderThresholdPatches, 2)
    }
}

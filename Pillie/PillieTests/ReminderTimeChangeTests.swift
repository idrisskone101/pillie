//
//  ReminderTimeChangeTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// A new reminder time applies from the next dose day. Days already lived keep the
/// status they had: a late dose never turns missed and a missed one never reopens
/// because the reminder moved.
@MainActor
final class ReminderTimeChangeTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?

    override func tearDown() {
        fixture = nil
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    private func day(_ iso: String) -> Date {
        Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate(iso, hour: 12))
    }

    private func at(_ iso: String, _ hour: Int, _ minute: Int = 0) -> Date {
        InMemoryStoreFactory.localDate(iso, hour: hour, minute: minute)
    }

    private func setNow(_ instant: Date, _ store: PillStore) {
        PillieClock.setFixedNowForTesting(instant)
        store.refreshDayContextIfNeeded()
    }

    /// 21/7 pack from 1 May, logged through 8 May, with the reminder at `hour`.
    private func makeStore(now: Date, reminderHour: Int) throws -> PillStore {
        let made = try InMemoryStoreFactory.makeStore(now: at("2026-05-08", 23), startDate: day("2026-05-01"))
        fixture = made
        let store = made.store
        store.reminderHour = reminderHour
        for date in ["2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06", "2026-05-07", "2026-05-08"] {
            store.markActionAsTaken(on: day(date))
        }
        setNow(now, store)
        return store
    }

    /// Reminder 10 PM. Pill 9 (9 May) is late; at 9 PM on 10 May the reminder moves to 8 PM.
    func testMovingTheReminderEarlierKeepsALateDoseOpenUntilItsDeadline() throws {
        let store = try makeStore(now: at("2026-05-10", 21), reminderHour: 22)
        XCTAssertEqual(store.today, day("2026-05-09"))

        ScheduleCriticalSettingChange.saveSettingsReminderTime(store: store, hour: 20, minute: 0)

        XCTAssertEqual(store.today, day("2026-05-09"))
        XCTAssertEqual(store.doseStanding(on: day("2026-05-09")), .late(until: at("2026-05-10", 22)))

        setNow(at("2026-05-10", 22, 1), store)

        XCTAssertEqual(store.statusForDate(day("2026-05-09")), .missed)
        XCTAssertEqual(store.today, day("2026-05-10"))

        setNow(at("2026-05-11", 20, 30), store)

        XCTAssertEqual(store.today, day("2026-05-11"))
    }

    /// Reminder 8 PM. Pill 9 was missed at 8 PM on 10 May and pill 10 logged at 8:05 PM;
    /// at 9 PM the reminder moves to 10 PM.
    func testMovingTheReminderLaterKeepsAMissedDoseMissed() throws {
        let store = try makeStore(now: at("2026-05-10", 20, 5), reminderHour: 20)
        store.markTodayAsTaken()
        setNow(at("2026-05-10", 21), store)
        XCTAssertEqual(store.statusForDate(day("2026-05-09")), .missed)
        XCTAssertEqual(store.currentStreak, 1)

        ScheduleCriticalSettingChange.saveSettingsReminderTime(store: store, hour: 22, minute: 0)

        XCTAssertEqual(store.today, day("2026-05-10"))
        XCTAssertEqual(store.statusForDate(day("2026-05-09")), .missed)
        XCTAssertTrue(store.isTodayTaken)
        XCTAssertEqual(store.currentStreak, 1)
    }

    /// Reminder 10 PM, pill 9 taken. At 10 AM on 10 May the reminder moves to 8 PM:
    /// tonight's pill 10 uses the new time.
    func testMovingTheReminderEarlierWithNothingLateAppliesTonight() throws {
        let store = try makeStore(now: at("2026-05-10", 10), reminderHour: 22)
        store.markTodayAsTaken()

        ScheduleCriticalSettingChange.saveSettingsReminderTime(store: store, hour: 20, minute: 0)
        setNow(at("2026-05-10", 20, 30), store)

        XCTAssertEqual(store.today, day("2026-05-10"))
        XCTAssertEqual(store.doseStanding(on: day("2026-05-10")), .late(until: at("2026-05-11", 20)))
    }

    /// The reminder for the day after a late dose fires at the time its window opens.
    func testTheReminderAfterALateDoseFiresWhenItsWindowOpens() throws {
        let store = try makeStore(now: at("2026-05-10", 21), reminderHour: 22)
        ScheduleCriticalSettingChange.saveSettingsReminderTime(store: store, hour: 20, minute: 0)

        let tenthReminder = KeptNotificationManager.make(hasBlockerSetup: { false })
            .managedRequestSummariesForTesting(store: store, now: at("2026-05-10", 21))
            .first { $0.dueDayEpoch == Int(day("2026-05-10").timeIntervalSince1970) && $0.requestKind == "base" }

        XCTAssertEqual(tenthReminder?.dateComponents.hour, 22)
    }
}

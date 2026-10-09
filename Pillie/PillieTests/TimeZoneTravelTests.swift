//
//  TimeZoneTravelTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// A pack's days are calendar dates. Flying to another time zone keeps each
/// logged day on its date and today's pill on its number.
@MainActor
final class TimeZoneTravelTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?
    /// Stores built mid-test stand in for later launches; they live for the process.
    private static var relaunchedStores: [PillStore] = []
    private var originalZone: TimeZone!

    override func setUp() {
        super.setUp()
        originalZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/Toronto")!
    }

    override func tearDown() {
        fixture = nil
        InMemoryStoreFactory.resetClockAndDefaults()
        NSTimeZone.default = originalZone
        super.tearDown()
    }

    private func fly(to identifier: String) {
        NSTimeZone.default = TimeZone(identifier: identifier)!
        XCTAssertEqual(Calendar.current.timeZone.identifier, identifier)
    }

    private func day(_ iso: String) -> Date {
        Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate(iso, hour: 12))
    }

    private func relaunch(_ fixture: InMemoryStoreFixture) -> PillStore {
        let store = PillStore(modelContext: fixture.context)
        Self.relaunchedStores.append(store)
        return store
    }

    /// Pill 1 on 1 October in Toronto; it is noon on 7 October, pill 7.
    private func torontoStore() throws -> InMemoryStoreFixture {
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate("2026-10-07", hour: 12),
            startDate: day("2026-10-01")
        )
        fixture = made
        return made
    }

    func testFlyingWestKeepsTodaysPillNumber() throws {
        let store = try torontoStore().store
        XCTAssertEqual(store.currentDayIndex + 1, 7)

        fly(to: "America/Vancouver")
        store.refreshDayContextIfNeeded()

        XCTAssertEqual(store.currentDayIndex + 1, 7)
    }

    func testFlyingWestKeepsYesterdaysCheckInOnYesterday() throws {
        let store = try torontoStore().store
        store.markActionAsTaken(on: day("2026-10-06"))
        XCTAssertEqual(store.statusForDate(day("2026-10-06")), .taken)

        fly(to: "America/Vancouver")
        store.refreshDayContextIfNeeded()

        XCTAssertEqual(store.statusForDate(day("2026-10-06")), .taken)
    }

    func testARoundTripWithLaunchesAbroadKeepsThePack() throws {
        let made = try torontoStore()
        for date in ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"] {
            made.store.markActionAsTaken(on: day(date))
        }
        try made.context.save()

        fly(to: "Europe/London")
        _ = relaunch(made)
        fly(to: "America/Toronto")
        let home = relaunch(made)

        XCTAssertEqual(home.currentDayIndex + 1, 7)
        XCTAssertEqual(home.statusForDate(day("2026-10-04")), .taken)
        XCTAssertEqual(home.pack.startDate, day("2026-10-01"))
    }

    /// The reminder for 6 Oct was planned in London; she checks in from it in Toronto.
    func testACheckInFromAReminderPlannedBeforeFlyingWestLogsItsDay() throws {
        fly(to: "Europe/London")
        let made = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate("2026-10-05", hour: 12),
            startDate: day("2026-10-01")
        )
        fixture = made
        let payload: [AnyHashable: Any] = [
            NotificationManager.PayloadKey.dueDayEpoch: Int(day("2026-10-06").timeIntervalSince1970),
            NotificationManager.PayloadKey.dueDayTimeZone: "Europe/London"
        ]

        fly(to: "America/Toronto")
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate("2026-10-06", hour: 8, minute: 1))
        made.store.refreshDayContextIfNeeded()
        let manager = KeptNotificationManager.make(hasBlockerSetup: { false })
        let dueDate = try XCTUnwrap(manager.dueDateFromPayload(userInfo: payload))
        manager.completeReminder(store: made.store, dueDate: dueDate)

        XCTAssertEqual(dueDate, day("2026-10-06"))
        XCTAssertTrue(made.store.isTodayTaken)
    }

    /// The shield extension reads the anchor the app wrote in Toronto after she lands in Vancouver.
    func testTheShieldScheduleKeepsTheLastActivePillAfterFlyingWest() throws {
        let mirror = try torontoStore().store.blockingScheduleMirror

        fly(to: "America/Vancouver")

        XCTAssertTrue(mirror.requiresAction(on: day("2026-10-21")))
        XCTAssertFalse(mirror.requiresAction(on: day("2026-10-22")))
    }
}

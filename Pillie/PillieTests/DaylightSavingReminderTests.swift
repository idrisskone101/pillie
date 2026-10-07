//
//  DaylightSavingReminderTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// A reminder set inside the hour clocks skip fires when its dose window opens.
@MainActor
final class DaylightSavingReminderTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?
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

    /// Toronto springs forward at 2:00 AM on 14 March 2027, so 2:30 AM never happens that day.
    func testASkippedHourReminderFiresWhenTheWindowOpens() throws {
        let now = InMemoryStoreFactory.localDate("2027-03-13", hour: 12)
        let made = try InMemoryStoreFactory.makeStore(
            now: now,
            startDate: Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate("2027-03-01", hour: 12))
        )
        fixture = made
        made.store.reminderHour = 2
        made.store.reminderMinute = 30
        let springForward = Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate("2027-03-14", hour: 12))

        let base = KeptNotificationManager.make(hasBlockerSetup: { false })
            .managedRequestSummariesForTesting(store: made.store, now: now)
            .first { $0.dueDayEpoch == Int(springForward.timeIntervalSince1970) && $0.requestKind == "base" }

        let windowOpens = try XCTUnwrap(made.store.reminderClock.reminder(on: springForward))
        XCTAssertEqual(Calendar.current.dateComponents([.hour, .minute], from: windowOpens), DateComponents(hour: 3, minute: 0))
        XCTAssertEqual(base?.dateComponents.hour, 3)
        XCTAssertEqual(base?.dateComponents.minute, 0)
    }
}

//
//  FallBackFollowUpTests.swift
//  PillieTests
//

import XCTest
import UserNotifications
@testable import Pillie

/// A follow-up fires a set time after its reminder, so on the night clocks fall back
/// one that lands in the repeated hour still fires after the reminder.
@MainActor
final class FallBackFollowUpTests: XCTestCase {
    /// Holds the in-memory container for the whole test; SwiftData resets models once it deallocates.
    private var fixture: InMemoryStoreFixture?
    private var originalZone: TimeZone!

    override func setUp() {
        super.setUp()
        originalZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
    }

    override func tearDown() {
        fixture = nil
        InMemoryStoreFactory.resetClockAndDefaults()
        NSTimeZone.default = originalZone
        super.tearDown()
    }

    /// New York falls back at 2:00 AM on 3 Nov 2030, so 1:00 to 1:59 AM happens twice. The
    /// 1:30 AM reminder fires in the first pass (05:30 UTC); its third follow-up, 30 minutes
    /// later, is 1:00 AM in the second pass (06:00 UTC).
    func testAFollowUpInTheRepeatedHourFiresAfterItsReminder() throws {
        let now = InMemoryStoreFactory.localDate("2030-11-03", hour: 0, minute: 40)
        let made = try InMemoryStoreFactory.makeStore(
            now: now,
            startDate: Calendar.current.startOfDay(for: InMemoryStoreFactory.localDate("2030-10-28", hour: 12))
        )
        fixture = made
        made.store.reminderHour = 1
        made.store.reminderMinute = 30
        made.store.autoReminderRetryLimit = 3
        let fallBackDay = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)

        let requests = KeptNotificationManager.make(center: InMemoryNotificationCenter(), hasPlusAccess: { true })
            .managedRequestSummariesForTesting(store: made.store, now: now)
            .filter { $0.dueDayEpoch == fallBackDay }
        let followUps = requests.filter { $0.requestKind == "retry" }

        XCTAssertEqual(requests.first { $0.requestKind == "base" }?.fireDate, Date(timeIntervalSince1970: 1_919_914_200))
        XCTAssertEqual(
            followUps.compactMap(\.fireDate).sorted(),
            [1_919_914_800, 1_919_915_400, 1_919_916_000].map { Date(timeIntervalSince1970: $0) }
        )
        XCTAssertEqual(
            followUps.compactMap { UNCalendarNotificationTrigger(dateMatching: $0.dateComponents, repeats: false).nextTriggerDate() }.sorted(),
            [1_919_914_800, 1_919_915_400, 1_919_916_000].map { Date(timeIntervalSince1970: $0) },
            "the system resolves a follow-up's trigger to another time"
        )
    }
}

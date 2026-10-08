//
//  ReminderRebuildTests.swift
//  PillieTests
//

import Foundation
import Testing
import UserNotifications

@testable import Pillie

/// What a reminder rebuild keeps and what it starts over, driven through
/// NotificationManager the way the app schedules. The rebuild reads the real clock,
/// so each test puts the reminder five minutes before now.
@MainActor
@Suite(.serialized)
struct ReminderRebuildTests {
    /// Five minutes ago is still today, so that reminder opened today's dose.
    nonisolated static var remindedToday: Bool {
        let now = Date()
        return Calendar.current.isDate(now.addingTimeInterval(-5 * 60), inSameDayAs: now)
    }

    /// Settings switches the pill to the patch, day 1 today, after the pill's reminder was served.
    @Test(.enabled(if: ReminderRebuildTests.remindedToday))
    func `A reset after the reminder gets the new routine's start-day catch-up`() async throws {
        let (fixture, todayEpoch) = try storeRemindedFiveMinutesAgo()
        defer { cleanUp() }
        let store = fixture.store
        let center = InMemoryNotificationCenter()
        let manager = KeptNotificationManager.make(center: center, hasPlusAccess: { false })

        store.resetAndStartFresh(
            method: .patch,
            regimen: .twentyOneSeven,
            customRegimen: nil,
            cycleDay: 1,
            anchorDay: store.anchorDay(for: nil)
        )
        // The reset asks NotificationManager.shared, which tests keep inert, so this manager stands in.
        manager.requestReschedule(from: store, reason: "full-reset")
        try await Task.sleep(for: .seconds(1))

        #expect(!center.pending.isEmpty, "the reset's rebuild did not run")
        let startDay = requests(center, kind: "base", dueDayEpoch: todayEpoch)
        #expect(startDay.count == 1, "the patch's first change gets no reminder")
        let fireDate = try #require(startDay.first.flatMap(NotificationManager.fireDate(from:)))
        #expect(fireDate.timeIntervalSinceNow <= 2 * 60)
    }

    /// A pill pack from three days ago whose reminder fired five minutes ago and was
    /// served: the ledger holds today's base reminder. Keep the fixture for the whole
    /// test; SwiftData resets its models once the container goes.
    private func storeRemindedFiveMinutesAgo() throws -> (fixture: InMemoryStoreFixture, todayEpoch: Int) {
        UserDefaults.standard.removeObject(forKey: ServedBaseReminderLedger.userDefaultsKey)
        let now = Date()
        let fixture = try InMemoryStoreFactory.makeStore(
            now: now,
            startDate: Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: now))
        )
        let store = fixture.store
        let reminder = Calendar.current.dateComponents([.hour, .minute], from: now.addingTimeInterval(-5 * 60))
        store.reminderHour = try #require(reminder.hour)
        store.reminderMinute = try #require(reminder.minute)
        let todayEpoch = Int(Calendar.current.startOfDay(for: store.today).timeIntervalSince1970)
        var ledger = ServedBaseReminderLedger()
        ledger.recordScheduled(dueDayEpoch: todayEpoch, fireDate: try #require(store.reminderClock.reminder(on: store.today)))
        ledger.save()
        return (fixture, todayEpoch)
    }

    private func requests(_ center: InMemoryNotificationCenter, kind: String, dueDayEpoch: Int) -> [UNNotificationRequest] {
        center.pending.filter {
            $0.content.userInfo["requestKind"] as? String == kind
                && $0.content.userInfo["dueDayEpoch"] as? Int == dueDayEpoch
        }
    }

    private func cleanUp() {
        UserDefaults.standard.removeObject(forKey: ServedBaseReminderLedger.userDefaultsKey)
        InMemoryStoreFactory.resetClockAndDefaults()
    }
}

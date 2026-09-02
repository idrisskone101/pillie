//
//  DueBaseReminderLedger.swift
//  Pillie
//

import Foundation
import UserNotifications

/// Persisted record of base Due Action Reminders the app actually committed to
/// schedule. Bounded to recent horizon; keyed by start-of-day epoch.
struct DueBaseReminderLedger: Codable, Equatable {
    private(set) var fireEpochByDueDayEpoch: [Int: Int]

    static let userDefaultsKey = "pillie_served_base_reminder_by_day"
    static let retentionDays = 14

    init(fireEpochByDueDayEpoch: [Int: Int] = [:]) {
        self.fireEpochByDueDayEpoch = fireEpochByDueDayEpoch
    }

    static func load() -> DueBaseReminderLedger {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let ledger = try? JSONDecoder().decode(DueBaseReminderLedger.self, from: data) else {
            return DueBaseReminderLedger()
        }
        return ledger
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    mutating func recordScheduled(dueDayEpoch: Int, fireDate: Date) {
        fireEpochByDueDayEpoch[dueDayEpoch] = Int(fireDate.timeIntervalSince1970)
    }

    mutating func prune(takenDueDayEpochs: Set<Int>, todayStart: Date, calendar: Calendar) {
        fireEpochByDueDayEpoch = fireEpochByDueDayEpoch.filter { dueDayEpoch, _ in
            !takenDueDayEpochs.contains(dueDayEpoch)
                && isWithinRetention(dueDayEpoch: dueDayEpoch, todayStart: todayStart, calendar: calendar)
        }
    }

    mutating func clear(dueDayEpoch: Int) -> DueBaseReminderLedger {
        fireEpochByDueDayEpoch.removeValue(forKey: dueDayEpoch)
        return self
    }

    func servedBaseFireDates(
        pendingManagedRequests: [UNNotificationRequest],
        deliveredManagedNotifications: [UNNotification],
        now: Date,
        calendar: Calendar
    ) -> [Int: Date] {
        var served: [Int: Date] = [:]
        for (dueDayEpoch, fireEpoch) in fireEpochByDueDayEpoch {
            served[dueDayEpoch] = Date(timeIntervalSince1970: TimeInterval(fireEpoch))
        }

        for request in pendingManagedRequests {
            guard let parsed = Self.parseBaseDueReminder(request) else { continue }
            served[parsed.dueDayEpoch] = parsed.fireDate
        }

        for notification in deliveredManagedNotifications {
            guard let parsed = Self.parseBaseDueReminder(notification.request),
                  parsed.fireDate <= now else { continue }
            served[parsed.dueDayEpoch] = parsed.fireDate
        }

        return served
    }

    private func isWithinRetention(dueDayEpoch: Int, todayStart: Date, calendar: Calendar) -> Bool {
        let dueDay = Date(timeIntervalSince1970: TimeInterval(dueDayEpoch))
        guard let horizonStart = calendar.date(
            byAdding: .day,
            value: -(Self.retentionDays - 1),
            to: todayStart
        ) else {
            return false
        }
        return dueDay >= horizonStart
    }

    private struct ParsedBaseDueReminder {
        let dueDayEpoch: Int
        let fireDate: Date
    }

    private static func parseBaseDueReminder(_ request: UNNotificationRequest) -> ParsedBaseDueReminder? {
        guard request.content.userInfo[SmartReminderDelivery.requestKindKey] as? String
            == ReminderSchedulePlanner.DueReminderKind.base.rawValue,
              let dueDayEpoch = request.content.userInfo[NotificationManager.PayloadKey.dueDayEpoch] as? Int,
              let fireDate = NotificationManager.fireDate(from: request) else {
            return nil
        }
        return ParsedBaseDueReminder(dueDayEpoch: dueDayEpoch, fireDate: fireDate)
    }
}

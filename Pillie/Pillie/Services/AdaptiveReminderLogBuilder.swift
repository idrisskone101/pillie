//
//  AdaptiveReminderLogBuilder.swift
//  Pillie
//

import Foundation

/// Builds the `(scheduledReminder, takenAt)` history that feeds
/// `AdaptiveReminderTimeAnalyzer`, derived from the user's logged days.
///
/// Pure and dependency-free: it maps day records to log pairs and performs no I/O.
/// A record only contributes a log when it carries an on-device `takenAt` timestamp;
/// its scheduled reminder is anchored to the reminder time-of-day on that calendar day.
enum AdaptiveReminderLogBuilder {
    static func logs(
        from records: [(date: Date, takenAt: Date?)],
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar = .current
    ) -> [(scheduledReminder: Date, takenAt: Date)] {
        records.compactMap { record in
            guard let takenAt = record.takenAt else { return nil }
            let startOfDay = calendar.startOfDay(for: record.date)
            guard let scheduled = calendar.date(
                bySettingHour: reminderHour,
                minute: reminderMinute,
                second: 0,
                of: startOfDay
            ) else { return nil }
            return (scheduledReminder: scheduled, takenAt: takenAt)
        }
    }
}

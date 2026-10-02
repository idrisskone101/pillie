//
//  DoseWindow.swift
//  Pillie
//

import Foundation

/// A due action stays completable until the next reminder, not calendar midnight.
/// The live day itself is `LiveDoseDay`, shared with the Screen Time extension.
enum DoseWindow {
    static func reminder(
        for day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: day))
    }

    static func deadline(
        for day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else {
            return nil
        }
        return reminder(for: nextDay, hour: hour, minute: minute, calendar: calendar)
    }

    static func isOpen(
        day: Date,
        now: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard let deadline = deadline(for: day, hour: hour, minute: minute, calendar: calendar) else {
            return calendar.startOfDay(for: day) >= calendar.startOfDay(for: now)
        }
        return now < deadline
    }

    /// DeviceActivity interval end: one minute before the next reminder, wrapping
    /// past midnight so shields stay up through the late window.
    static func blockingIntervalEnd(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        if minute > 0 {
            return (hour, minute - 1)
        }
        if hour > 0 {
            return (hour - 1, 59)
        }
        return (23, 59)
    }

    static func deviceActivityBounds(
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> (start: DateComponents, end: DateComponents) {
        let end = blockingIntervalEnd(hour: hour, minute: minute)
        return (
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                hour: hour,
                minute: minute
            ),
            DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                hour: end.hour,
                minute: end.minute
            )
        )
    }
}

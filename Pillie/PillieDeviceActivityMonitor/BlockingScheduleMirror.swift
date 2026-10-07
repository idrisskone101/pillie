//
//  BlockingScheduleMirror.swift
//  Shared between Pillie and DeviceActivityMonitor. Keep copies byte-identical.
//

import Foundation

struct BlockingScheduleMirror: Codable, Equatable {
    static let storageKey = "pillie_blocking_schedule_data"

    let anchorDate: Date
    let anchorCycleDayIndex: Int
    let cycleLength: Int
    let actionDayIndices: [Int]
    /// The time zone `anchorDate` was written in; nil in mirrors from older builds.
    let timeZoneIdentifier: String?

    init(
        anchorDate: Date,
        anchorCycleDayIndex: Int,
        cycleLength: Int,
        actionDayIndices: [Int],
        timeZoneIdentifier: String? = nil
    ) {
        let safeCycleLength = max(1, cycleLength)
        self.anchorDate = anchorDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.anchorCycleDayIndex = Self.normalizedIndex(
            anchorCycleDayIndex,
            cycleLength: safeCycleLength
        )
        self.cycleLength = safeCycleLength
        self.actionDayIndices = Array(Set(actionDayIndices.filter {
            (0..<safeCycleLength).contains($0)
        })).sorted()
    }

    func encodedData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data?) -> BlockingScheduleMirror? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(BlockingScheduleMirror.self, from: data)
    }

    /// Uses a periodic cycle rule, so the extension can make the right choice
    /// across a full break week and resume on the next active day without the
    /// main app waking in between.
    func requiresAction(on date: Date, calendar: Calendar = .current) -> Bool {
        guard cycleLength > 0,
              actionDayIndices.contains(where: { (0..<cycleLength).contains($0) }) else {
            // A corrupt/empty mirror must not silently disable protection.
            return true
        }

        let anchorDay = StoredDay.day(of: anchorDate, writtenIn: timeZoneIdentifier, calendar: calendar)
        let targetDay = calendar.startOfDay(for: date)
        guard let dayDelta = calendar.dateComponents(
            [.day],
            from: anchorDay,
            to: targetDay
        ).day else {
            // Invalid mirrored state preserves the existing fail-toward-blocking
            // behavior instead of silently disabling protection.
            return true
        }

        let targetIndex = Self.normalizedIndex(
            anchorCycleDayIndex + dayDelta,
            cycleLength: cycleLength
        )
        return actionDayIndices.contains(targetIndex)
    }

    private static func normalizedIndex(_ value: Int, cycleLength: Int) -> Int {
        let modulo = value % cycleLength
        return modulo >= 0 ? modulo : modulo + cycleLength
    }
}

enum BlockingInterventionDecision: Equatable {
    case applyShields
    case clearShields
}

/// Pillie stores a day as the instant of its local midnight. Read in another time
/// zone that instant can fall on the previous evening, so a stored day is read in
/// the zone it was written in and becomes the same date in `calendar`.
enum StoredDay {
    static func day(of stored: Date, writtenIn identifier: String?, calendar: Calendar = .current) -> Date {
        guard let identifier,
              identifier != calendar.timeZone.identifier,
              let writtenZone = TimeZone(identifier: identifier) else {
            return calendar.startOfDay(for: stored)
        }
        var written = calendar
        written.timeZone = writtenZone
        let date = written.dateComponents([.year, .month, .day], from: stored)
        return calendar.date(from: date).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: stored)
    }
}

/// The day a due action belongs to: from one reminder to the next, not civil
/// midnight. The app, History, streak, and shields all read this one clock.
enum LiveDoseDay {
    static func on(
        _ now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        guard
            let reminder = calendar.date(
                bySettingHour: reminderHour,
                minute: reminderMinute,
                second: 0,
                of: today
            ),
            now < reminder,
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        else {
            return today
        }
        return yesterday
    }
}

enum BlockingInterventionPolicy {
    static func decision(
        schedule: BlockingScheduleMirror?,
        handledStamp: TodayTakenStamp,
        now: Date,
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        calendar: Calendar = .current
    ) -> BlockingInterventionDecision {
        let day = LiveDoseDay.on(
            now,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            calendar: calendar
        )
        if let schedule, !schedule.requiresAction(on: day, calendar: calendar) {
            return .clearShields
        }
        if handledStamp.isTaken(on: day, calendar: calendar)
            || handledStamp.isWritten(after: day, calendar: calendar) {
            return .clearShields
        }
        return .applyShields
    }
}

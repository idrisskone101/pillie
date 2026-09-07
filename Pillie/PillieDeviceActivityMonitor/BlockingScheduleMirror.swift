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

    init(
        anchorDate: Date,
        anchorCycleDayIndex: Int,
        cycleLength: Int,
        actionDayIndices: [Int]
    ) {
        let safeCycleLength = max(1, cycleLength)
        self.anchorDate = anchorDate
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

        let anchorDay = calendar.startOfDay(for: anchorDate)
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

enum BlockingInterventionPolicy {
    static func decision(
        schedule: BlockingScheduleMirror?,
        handledStamp: TodayTakenStamp,
        now: Date,
        calendar: Calendar = .current,
        snoozeUntil: Date? = nil
    ) -> BlockingInterventionDecision {
        if let snoozeUntil, now < snoozeUntil {
            return .clearShields
        }
        if let schedule, !schedule.requiresAction(on: now, calendar: calendar) {
            return .clearShields
        }
        if handledStamp.isTakenToday(now: now, calendar: calendar) {
            return .clearShields
        }
        return .applyShields
    }
}

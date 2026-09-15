//
//  ActiveDaySchedule.swift
//  Pillie
//

import Foundation

/// Pack rhythm without SwiftData. Reverse Trial walks this snapshot instead of
/// a live `PillPack`, so the clock never holds a model object.
struct ActiveDaySchedule: Equatable, Sendable {
    var anchorDate: Date
    var anchorDayIndex: Int
    var activeDays: Int
    var cycleLength: Int

    /// Continuous regimens and missing pack: every local day is active-phase.
    static let everyCalendarDay = ActiveDaySchedule(
        anchorDate: Date(timeIntervalSince1970: 0),
        anchorDayIndex: 0,
        activeDays: 1,
        cycleLength: 1
    )

    init(anchorDate: Date, anchorDayIndex: Int, activeDays: Int, cycleLength: Int) {
        let length = max(1, cycleLength)
        let modulo = anchorDayIndex % length
        self.anchorDate = anchorDate
        self.anchorDayIndex = modulo >= 0 ? modulo : modulo + length
        self.activeDays = min(max(0, activeDays), length)
        self.cycleLength = length
    }

    init(pack: PillPack) {
        let anchor = pack.resolvedCycleAnchor()
        self.init(
            anchorDate: anchor.date,
            anchorDayIndex: anchor.dayIndex,
            activeDays: pack.activeDays,
            cycleLength: pack.cycleLength
        )
    }

    func cycleDayIndex(on date: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: anchorDate)
        let target = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        let elapsed = diff + anchorDayIndex
        let modulo = elapsed % cycleLength
        return modulo >= 0 ? modulo : modulo + cycleLength
    }

    func isActiveDay(_ date: Date, calendar: Calendar) -> Bool {
        if self == .everyCalendarDay { return true }
        return cycleDayIndex(on: date, calendar: calendar) < activeDays
    }
}

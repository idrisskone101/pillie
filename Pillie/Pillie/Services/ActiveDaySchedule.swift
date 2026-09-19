//
//  ActiveDaySchedule.swift
//  Pillie
//

import Foundation

/// Pack rhythm without SwiftData. Reverse Trial walks this snapshot instead of
/// a live `PillPack`, so the clock never holds a model object.
///
/// Hormone-active means `DoseScheduleEngine.dueAction?.isBreak == false`,
/// stored as 0-based cycle indices. Patch and ring remove (day 22 / index 21
/// on a 21/7) is hormone-active. Placebo / patch-off / ring-off is not.
/// `PillPack.isBreakDay` is the wrong predicate — it treats that remove day
/// as a break.
struct ActiveDaySchedule: Equatable, Sendable {
    var anchorDate: Date
    var anchorDayIndex: Int
    var cycleLength: Int
    var hormoneActiveIndices: Set<Int>

    /// Continuous regimens, missing pack, and calendar-clock tests.
    static let everyCalendarDay = ActiveDaySchedule(
        anchorDate: Date(timeIntervalSince1970: 0),
        anchorDayIndex: 0,
        cycleLength: 1,
        hormoneActiveIndices: [0]
    )

    init(
        anchorDate: Date,
        anchorDayIndex: Int,
        cycleLength: Int,
        hormoneActiveIndices: Set<Int>
    ) {
        let length = max(1, cycleLength)
        self.anchorDate = anchorDate
        self.anchorDayIndex = Self.normalizedIndex(anchorDayIndex, cycleLength: length)
        self.cycleLength = length
        let normalized = Set(
            hormoneActiveIndices.map { Self.normalizedIndex($0, cycleLength: length) }
        )
        // An empty set never reaches 14 full days. Fail toward counting every
        // index so Plus cannot stay on forever from a corrupt snapshot.
        self.hormoneActiveIndices = normalized.isEmpty ? Set(0..<length) : normalized
    }

    /// Pill-prefix convenience for tests: indices `0..<activeDays` consume.
    /// Do not use this for patch or ring — day 22 is hormone-active.
    init(anchorDate: Date, anchorDayIndex: Int, activeDays: Int, cycleLength: Int) {
        let length = max(1, cycleLength)
        let count = min(max(0, activeDays), length)
        self.init(
            anchorDate: anchorDate,
            anchorDayIndex: anchorDayIndex,
            cycleLength: length,
            hormoneActiveIndices: count == 0 ? [] : Set(0..<count)
        )
    }

    /// Snapshot the live pack. A missing pack is every calendar day — never a
    /// fabricated 21/7. Continuous packs (every index hormone-active) collapse
    /// to `.everyCalendarDay` as well.
    init(pack: PillPack?, calendar: Calendar = .current) {
        guard let pack else {
            self = .everyCalendarDay
            return
        }

        let cycleLength = max(1, pack.cycleLength)
        let anchor = pack.resolvedCycleAnchor()
        let origin = calendar.startOfDay(for: anchor.date)
        var indices: Set<Int> = []
        for offset in 0..<cycleLength {
            guard
                let date = calendar.date(byAdding: .day, value: offset, to: origin),
                let action = DoseScheduleEngine.dueAction(on: date, pack: pack, calendar: calendar),
                !action.isBreak
            else { continue }
            indices.insert(action.cycleDay - 1)
        }

        if indices.isEmpty || indices.count == cycleLength {
            self = .everyCalendarDay
            return
        }

        self.init(
            anchorDate: origin,
            anchorDayIndex: anchor.dayIndex,
            cycleLength: cycleLength,
            hormoneActiveIndices: indices
        )
    }

    init(pack: PillPack, calendar: Calendar = .current) {
        self.init(pack: Optional(pack), calendar: calendar)
    }

    func cycleDayIndex(on date: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: anchorDate)
        let target = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return Self.normalizedIndex(anchorDayIndex + diff, cycleLength: cycleLength)
    }

    func isActiveDay(_ date: Date, calendar: Calendar) -> Bool {
        if hormoneActiveIndices.count == cycleLength { return true }
        return hormoneActiveIndices.contains(cycleDayIndex(on: date, calendar: calendar))
    }

    private static func normalizedIndex(_ value: Int, cycleLength: Int) -> Int {
        let modulo = value % cycleLength
        return modulo >= 0 ? modulo : modulo + cycleLength
    }
}

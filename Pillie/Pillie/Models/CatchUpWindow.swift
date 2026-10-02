//
//  CatchUpWindow.swift
//  Pillie
//

import Foundation

/// A missed patch or ring task stays loggable from Home until the next task day or the end of the cycle.
/// The ring's day 29 reinsert has no window: from day 30 Home offers Start new instead.
enum CatchUpWindow {
    /// The cycle day of the task today's catch-up would log, or nil when today has its own task or the cycle is over.
    static func taskDay(on cycleDay: Int, method: RoutineDialMethod) -> Int? {
        guard cycleDay <= RoutineDialDay.cycleLength,
              let last = RoutineDialDay.taskDays(method: method).last(where: { $0 <= cycleDay }),
              last < cycleDay else { return nil }
        return last
    }
}

/// The missed task in today's catch-up window and when it was logged late, if it was.
struct CatchUp: Equatable {
    let action: DoseScheduleAction
    let caughtUpAt: Date?
}

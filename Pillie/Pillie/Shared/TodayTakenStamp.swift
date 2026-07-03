//
//  TodayTakenStamp.swift
//  Pillie
//
//  Day-scoped "today taken" flag shared with the DeviceActivityMonitor
//  extension. The bare Bool it replaces went stale overnight: the app only
//  rewrites it while running, so yesterday's true silently cancelled today's
//  blocking at Due Action Time. Pairing the flag with the day it was written
//  lets the extension reject stale state on its own.
//

import Foundation

struct TodayTakenStamp: Equatable {
    let isTaken: Bool
    /// Start-of-day epoch seconds for the day the flag was written; nil for
    /// legacy installs that only ever wrote the Bool.
    let epochDay: Int?

    static func epochDay(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    /// True only when the flag is set AND was written today. A missing or
    /// mismatched stamp fails toward blocking: a dismissible shield beats
    /// silently skipped protection.
    func isTakenToday(now: Date, calendar: Calendar = .current) -> Bool {
        isTaken && epochDay == Self.epochDay(for: now, calendar: calendar)
    }
}

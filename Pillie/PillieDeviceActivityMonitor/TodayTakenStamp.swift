//
//  TodayTakenStamp.swift
//  Shared value type — keep in sync with Pillie/Shared/TodayTakenStamp.swift
//
//  Day-scoped handled flag shared with the DeviceActivityMonitor extension.
//  Legacy symbol/key names still say "taken," but true also covers a scheduled
//  break or passive day. Pairing the Bool with its day lets the extension reject
//  yesterday's completed action without mistaking it for today's state.
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

    /// True only when the handled flag is set AND was written today. A missing or
    /// mismatched stamp fails toward blocking: a dismissible shield beats
    /// silently skipped protection.
    func isTakenToday(now: Date, calendar: Calendar = .current) -> Bool {
        isTaken && epochDay == Self.epochDay(for: now, calendar: calendar)
    }
}

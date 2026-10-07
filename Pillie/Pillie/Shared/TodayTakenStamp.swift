//
//  TodayTakenStamp.swift
//  Pillie
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

    /// The calendar day the stamp was written for: the local midnight nearest
    /// `epochDay`, so a stamp written before a time zone change keeps its date.
    func day(calendar: Calendar = .current) -> Date? {
        epochDay.map { calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval($0) + 12 * 60 * 60)) }
    }

    /// True only when the handled flag is set AND was written for `day`.
    func isTaken(on day: Date, calendar: Calendar = .current) -> Bool {
        isTaken && self.day(calendar: calendar) == calendar.startOfDay(for: day)
    }

    /// True when the stamp names a day after `day`. The app's today runs ahead of
    /// the clock's live day only on a day set up before its first reminder, and the
    /// live day it passed over was settled in that setup.
    func isWritten(after day: Date, calendar: Calendar = .current) -> Bool {
        guard let stampDay = self.day(calendar: calendar) else { return false }
        return stampDay > calendar.startOfDay(for: day)
    }

    /// True only when the handled flag is set AND was written for the live
    /// dose day of `now`. A missing or mismatched stamp fails toward blocking.
    func isTakenToday(now: Date, calendar: Calendar = .current) -> Bool {
        isTaken(on: calendar.startOfDay(for: now), calendar: calendar)
    }
}

//
//  PillieClock.swift
//  Pillie
//

import Foundation

enum PillieClock {
    #if DEBUG
    private static var fixedNow: Date?

    static func setFixedNowForTesting(_ date: Date?) {
        fixedNow = date
    }

    static func debugDate(from raw: String) -> Date? {
        if let seconds = TimeInterval(raw) {
            return Date(timeIntervalSince1970: seconds)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    static func withFixedNowForTesting<T>(_ date: Date, _ body: () throws -> T) rethrows -> T {
        let previous = fixedNow
        fixedNow = date
        defer { fixedNow = previous }
        return try body()
    }
    #endif

    static var now: Date {
        #if DEBUG
        if let fixedNow {
            return fixedNow
        }
        if let override = ProcessInfo.processInfo.environment["PILLIE_FIXED_NOW"],
           let date = debugDate(from: override) {
            return date
        }
        #endif
        return Date()
    }

    static var today: Date {
        Calendar.current.startOfDay(for: now)
    }
}

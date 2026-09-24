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
           let date = ISO8601DateFormatter().date(from: override) {
            return date
        }
        #endif
        return Date()
    }

    static var today: Date {
        Calendar.current.startOfDay(for: now)
    }
}

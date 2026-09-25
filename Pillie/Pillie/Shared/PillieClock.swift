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
        #endif
        return Date()
    }

    static var today: Date {
        Calendar.current.startOfDay(for: now)
    }
}

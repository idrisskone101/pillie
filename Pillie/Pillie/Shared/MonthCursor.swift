//
//  MonthCursor.swift
//  Pillie
//

import Foundation

enum MonthCursor {
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: components) else {
            return calendar.startOfDay(for: date)
        }
        return calendar.startOfDay(for: monthStart)
    }

    static func month(byAdding value: Int, to date: Date, calendar: Calendar = .current) -> Date {
        let anchor = monthStart(for: date, calendar: calendar)
        guard let shifted = calendar.date(byAdding: .month, value: value, to: anchor) else {
            return anchor
        }
        return monthStart(for: shifted, calendar: calendar)
    }
}

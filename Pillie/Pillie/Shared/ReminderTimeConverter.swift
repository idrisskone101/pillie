//
//  ReminderTimeConverter.swift
//  Pillie
//

import Foundation

enum ReminderTimeConverter {
    static func toTwelveHour(hour24: Int, minute: Int) -> (hour: Int, minute: Int, period: Int) {
        let safeHour24 = min(max(hour24, 0), 23)
        let safeMinute = min(max(minute, 0), 59)

        if safeHour24 == 0 {
            return (12, safeMinute, 0)
        }
        if safeHour24 < 12 {
            return (safeHour24, safeMinute, 0)
        }
        if safeHour24 == 12 {
            return (12, safeMinute, 1)
        }
        return (safeHour24 - 12, safeMinute, 1)
    }

    static func toTwentyFourHour(hour: Int, minute: Int, period: Int) -> (hour: Int, minute: Int) {
        let safeHour = min(max(hour, 1), 12)
        let safeMinute = min(max(minute, 0), 59)
        let safePeriod = period == 1 ? 1 : 0

        var hour24 = safeHour % 12
        if safePeriod == 1 {
            hour24 += 12
        }
        return (hour24, safeMinute)
    }
}

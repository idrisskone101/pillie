//
//  CalendarMonthLayout.swift
//  Pillie
//

import Foundation

/// History's month page is a fixed 6×7 grid. Months that occupy 4 or 5 weeks
/// keep trailing empty slots so a swipe never changes the page height.
enum CalendarMonthLayout {
    static let reservedWeekCount = 6
    static let daysInWeek = 7
    static var reservedSlotCount: Int { reservedWeekCount * daysInWeek }

    static func weekCount(daysInMonth: Int, firstWeekdayOffset: Int) -> Int {
        let occupied = max(0, firstWeekdayOffset) + max(0, daysInMonth)
        return max(1, (occupied + daysInWeek - 1) / daysInWeek)
    }
}

#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct CalendarMonthLayoutTests {
    @Test func reservedGridIsAlwaysSixWeeks() {
        #expect(CalendarMonthLayout.reservedWeekCount == 6)
        #expect(CalendarMonthLayout.reservedSlotCount == 42)
    }

    @Test func februaryStartingOnSundayUsesFourWeeks() {
        #expect(CalendarMonthLayout.weekCount(daysInMonth: 28, firstWeekdayOffset: 0) == 4)
    }

    @Test func thirtyOneDayMonthStartingOnSaturdayUsesSixWeeks() {
        #expect(CalendarMonthLayout.weekCount(daysInMonth: 31, firstWeekdayOffset: 6) == 6)
    }

    @Test func reservedSlotsCoverTheTallestMonth() {
        #expect(
            CalendarMonthLayout.reservedSlotCount
                >= CalendarMonthLayout.weekCount(daysInMonth: 31, firstWeekdayOffset: 6) * 7
        )
    }
}
#endif

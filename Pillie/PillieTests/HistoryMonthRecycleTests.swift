#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct HistoryMonthRecycleTests {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.locale = Locale(identifier: "en_US_POSIX")
        return value
    }()

    @Test func firstForwardSwipeKeepsCenterBound() {
        let window = seededWindow()
        let plan = HistoryMonthRecyclePlan.apply(
            delta: 1,
            months: window.months,
            boundMonths: window.bound,
            calendar: calendar
        )

        #expect(plan.centerNeedsBind == false)
        #expect(MonthCursor.identity(for: plan.months[1], calendar: calendar) == "2026-9")
        #expect(plan.incomingIndex == 2)
        #expect(MonthCursor.identity(for: plan.incomingMonth, calendar: calendar) == "2026-10")
        #expect(plan.boundMonths[2].map { MonthCursor.identity(for: $0, calendar: calendar) } == "2026-7")
    }

    @Test func secondFastForwardSwipeLeavesCenterStale() {
        let window = seededWindow()
        let first = HistoryMonthRecyclePlan.apply(
            delta: 1,
            months: window.months,
            boundMonths: window.bound,
            calendar: calendar
        )
        let second = HistoryMonthRecyclePlan.apply(
            delta: 1,
            months: first.months,
            boundMonths: first.boundMonths,
            calendar: calendar
        )

        #expect(second.centerNeedsBind == true)
        #expect(MonthCursor.identity(for: second.months[1], calendar: calendar) == "2026-10")
        #expect(second.boundMonths[1].map { MonthCursor.identity(for: $0, calendar: calendar) } == "2026-7")
    }

    @Test func bindingCenterClearsTheStaleFlag() {
        let window = seededWindow()
        let first = HistoryMonthRecyclePlan.apply(
            delta: 1,
            months: window.months,
            boundMonths: window.bound,
            calendar: calendar
        )
        var second = HistoryMonthRecyclePlan.apply(
            delta: 1,
            months: first.months,
            boundMonths: first.boundMonths,
            calendar: calendar
        )
        second.boundMonths[1] = second.months[1]

        #expect(second.centerNeedsBind == false)
    }

    private func seededWindow() -> (months: [Date], bound: [Date?]) {
        let july = month(2026, 7)
        let august = month(2026, 8)
        let september = month(2026, 9)
        return ([july, august, september], [july, august, september])
    }

    private func month(_ year: Int, _ month: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return MonthCursor.monthStart(
            for: calendar.date(from: components) ?? Date(timeIntervalSince1970: 0),
            calendar: calendar
        )
    }
}
#endif

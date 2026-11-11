//
//  TrialDayRuleTests.swift
//  PillieTests
//
//  ENG-242: only an install from this release on counts 14 calendar days.
//

import Foundation
import Testing

@testable import Pillie

@MainActor
struct TrialDayRuleTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    @Test func freshInstallCountsCalendarDays() {
        let rule = TrialDayRule.assignment(hasExistingAppState: false, hasTrialGrant: false, previous: nil)

        #expect(rule == .calendarDays)
    }

    @Test func installWithAppStateCountsActiveDays() {
        let rule = TrialDayRule.assignment(hasExistingAppState: true, hasTrialGrant: false, previous: nil)

        #expect(rule == .activeDays)
    }

    @Test func reinstallWithKeychainGrantCountsActiveDays() {
        let rule = TrialDayRule.assignment(hasExistingAppState: false, hasTrialGrant: true, previous: nil)

        #expect(rule == .activeDays)
    }

    @Test func storedRuleNeverFlips() {
        let store = InMemoryTrialGrantStore()
        let defaults = UserDefaults(suiteName: "TrialDayRuleTests.storedRuleNeverFlips")!
        defaults.removePersistentDomain(forName: "TrialDayRuleTests.storedRuleNeverFlips")

        let first = TrialDayRule.recordAssignment(hasExistingAppState: false, store: store, defaults: defaults)
        store.saveGrantDate(date(7, 1, 10))
        let second = TrialDayRule.recordAssignment(hasExistingAppState: true, store: store, defaults: defaults)

        #expect(first == .calendarDays)
        #expect(second == .calendarDays)
        #expect(store.loadDayRule() == .calendarDays)
        #expect(TrialDayRule.stored(in: defaults) == .calendarDays)
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
}

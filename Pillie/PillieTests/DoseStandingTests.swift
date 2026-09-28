//
//  DoseStandingTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct DoseStandingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func standing(
        _ action: PillDay.ActionType? = .pillActive,
        _ status: PillDay.Status = .upcoming,
        packStartedAt: Date? = nil,
        now: Date
    ) -> DoseStanding? {
        DoseStanding.resolve(
            action: action, status: status, day: at(day: 28, hour: 0), packStartedAt: packStartedAt, now: now,
            reminderHour: 20, reminderMinute: 0, calendar: calendar
        )
    }

    @Test func `An unlogged pill is upcoming until its reminder`() {
        #expect(standing(now: at(day: 28, hour: 19, minute: 59)) == .upcoming)
    }

    @Test func `An unlogged pill is late from its reminder while its window is open`() {
        let nextReminder = at(day: 29, hour: 20)

        #expect(standing(now: at(day: 28, hour: 20)) == .late(until: nextReminder))
        #expect(standing(now: at(day: 29, hour: 19, minute: 59)) == .late(until: nextReminder))
    }

    @Test func `A pill whose window closed unlogged is missed`() {
        #expect(standing(.pillActive, .missed, now: at(day: 29, hour: 20)) == .missed)
    }

    @Test func `A pill logged late is taken`() {
        #expect(standing(.pillActive, .taken, now: at(day: 29, hour: 10)) == .taken)
    }

    @Test func `A patch change goes late like a pill`() {
        #expect(standing(.patchChange, now: at(day: 28, hour: 21)) == .late(until: at(day: 29, hour: 20)))
    }

    @Test func `A pack started before its first day's reminder goes late as usual`() {
        let started = at(day: 28, hour: 19)

        #expect(standing(packStartedAt: started, now: at(day: 28, hour: 20, minute: 30)) == .late(until: at(day: 29, hour: 20)))
    }

    @Test func `A pack started after its first day's reminder stays upcoming until the next reminder`() {
        let started = at(day: 28, hour: 21)

        #expect(standing(packStartedAt: started, now: at(day: 28, hour: 22)) == .upcoming)
        #expect(standing(packStartedAt: started, now: at(day: 29, hour: 19, minute: 59)) == .upcoming)
        #expect(standing(.pillActive, .missed, packStartedAt: started, now: at(day: 29, hour: 20)) == .missed)
    }

    @Test func `A pack started after midnight inside the window gets no grace`() {
        #expect(standing(packStartedAt: at(day: 29, hour: 7), now: at(day: 29, hour: 8)) == .late(until: at(day: 29, hour: 20)))
    }

    @Test func `A pack from an older build has no start instant and no grace`() {
        #expect(standing(packStartedAt: nil, now: at(day: 28, hour: 22)) == .late(until: at(day: 29, hour: 20)))
    }

    @Test func `Days that cannot slip have no standing`() {
        let later = at(day: 30, hour: 9)

        #expect(standing(.pillBreak, .breakDay, now: later) == nil)
        #expect(standing(.pillSugar, .breakDay, now: later) == nil)
        #expect(standing(.pillSugar, .upcoming, now: at(day: 28, hour: 21)) == nil)
        #expect(standing(.patchActive, .upcoming, now: later) == nil)
        #expect(standing(.pillActive, .breakDay, now: later) == nil)
        #expect(standing(.pillActive, .noData, now: later) == nil)
        #expect(standing(nil, .missed, now: later) == nil)
    }
}

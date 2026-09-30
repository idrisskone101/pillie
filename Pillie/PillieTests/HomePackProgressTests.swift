//
//  HomePackProgressTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HomePackProgressTests {
    private let english = Locale(identifier: "en")
    private let reminderTime = "9:00 PM"
    private let twentyOneSeven = PackRegimen(activeDays: 21, breakDays: 7)
    private let twentyOneFour = PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Monday, 28 September 2026.
    private var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!
    }

    private var mondayEvening: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 22))!
    }

    private var deadline: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 21))!
    }

    private func progress(
        _ regimen: PackRegimen,
        elapsed: Int,
        taken: Bool = false,
        missed: Set<Int> = [],
        lateUntil: Date? = nil,
        now: Date? = nil
    ) -> HomePackProgress {
        HomePackProgress(
            regimen: regimen,
            elapsedDays: elapsed,
            isTodayTaken: taken,
            missedDays: missed,
            lateUntil: lateUntil,
            today: monday,
            now: now ?? monday,
            calendar: calendar
        )
    }

    private func header(_ progress: HomePackProgress) -> [String] {
        [progress.title(locale: english), progress.subtitle(reminderTime: reminderTime, locale: english)]
    }

    // MARK: Header

    @Test func `A finished pack says so, even if today was logged`() {
        let finished = progress(twentyOneSeven, elapsed: 28, taken: true)

        #expect(finished.status == .finished)
        #expect(header(finished) == ["Pack finished", "Every pill is out"])
    }

    @Test func `A logged pill reads taken today`() {
        #expect(header(progress(twentyOneSeven, elapsed: 11, taken: true)) == ["Pill 12 of 28", "Taken today"])
        #expect(header(progress(twentyOneSeven, elapsed: 23, taken: true)) == ["Sugar pill 3 of 7", "Taken today"])
    }

    @Test func `A pill-free break day names the next pack's weekday`() {
        #expect(header(progress(twentyOneFour, elapsed: 22)) == ["Break day 2 of 4", "Nothing to take · new pack Thursday"])
    }

    @Test func `A sugar pill day counts the sugar pills and names the next pack's weekday`() {
        #expect(header(progress(twentyOneSeven, elapsed: 23)) == ["Sugar pill 3 of 7", "Pill 24 of 28 · new pack Saturday"])
    }

    @Test func `Pill 1 names the pack`() {
        #expect(header(progress(twentyOneSeven, elapsed: 0)) == ["Pill 1 of 28", "New pack · Standard"])
        #expect(header(progress(PackRegimen(activeDays: 88, breakDays: 3), elapsed: 0)) == ["Pill 1 of 91", "New pack · 88 + 3"])
    }

    @Test func `The last hormone pill says what comes next`() {
        #expect(header(progress(twentyOneSeven, elapsed: 20)) == ["Pill 21 of 28", "Last hormone pill · sugar pills next"])
        #expect(header(progress(twentyOneFour, elapsed: 20)) == ["Pill 21 of 25", "Last hormone pill · break starts tomorrow"])
    }

    @Test func `A pack without a break has no last hormone pill`() {
        let everyDay = PackRegimen(activeDays: 28, breakDays: 0)

        #expect(header(progress(everyDay, elapsed: 27)) == ["Pill 28 of 28", "Every day · due 9:00 PM"])
    }

    @Test func `Any other pill day shows the pack and the reminder time`() {
        let twentyFourFour = PackRegimen(activeDays: 24, breakDays: 4)

        #expect(header(progress(twentyFourFour, elapsed: 11)) == ["Pill 12 of 28", "24/4 · due 9:00 PM"])
    }

    @Test func `A late pill keeps its title and says the window closes tomorrow before midnight`() {
        let late = progress(twentyOneSeven, elapsed: 11, lateUntil: deadline, now: mondayEvening)

        #expect(late.status == .late(endsTomorrow: true))
        #expect(header(late) == ["Pill 12 of 28", "Late · still time until 9:00 PM tomorrow"])
    }

    @Test func `A late pill says today once midnight has passed`() {
        let pastMidnight = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 1))!
        let late = progress(twentyOneSeven, elapsed: 11, lateUntil: deadline, now: pastMidnight)

        #expect(header(late) == ["Pill 12 of 28", "Late · still time until 9:00 PM today"])
    }

    @Test func `Late overrides the first and last pill lines`() {
        #expect(header(progress(twentyOneSeven, elapsed: 0, lateUntil: deadline, now: mondayEvening))
            == ["Pill 1 of 28", "Late · still time until 9:00 PM tomorrow"])
        #expect(header(progress(twentyOneSeven, elapsed: 20, lateUntil: deadline, now: mondayEvening))
            == ["Pill 21 of 28", "Late · still time until 9:00 PM tomorrow"])
    }

    @Test func `A pill missed yesterday names it under the live day's title`() {
        #expect(header(progress(twentyOneSeven, elapsed: 11, missed: [10])) == ["Pill 12 of 28", "Pill 11 missed yesterday"])
    }

    @Test func `Missed yesterday outranks today's late line`() {
        let both = progress(twentyOneSeven, elapsed: 11, missed: [10], lateUntil: deadline, now: mondayEvening)

        #expect(both.status == .missedYesterday(pillNumber: 11))
        #expect(both.marks == [10: .missed, 11: .late])
    }

    @Test func `Taken today outranks missed yesterday`() {
        #expect(header(progress(twentyOneSeven, elapsed: 11, taken: true, missed: [10])) == ["Pill 12 of 28", "Taken today"])
    }

    @Test func `An older miss leaves the header on the live pill`() {
        #expect(header(progress(twentyOneSeven, elapsed: 11, missed: [4])) == ["Pill 12 of 28", "Standard · due 9:00 PM"])
    }

    // MARK: Card inputs

    @Test func `Missed days and a late today draw as missed and late tiles`() {
        let card = progress(twentyOneSeven, elapsed: 11, missed: [3, 9], lateUntil: deadline, now: mondayEvening)
        let layout = PackCardLayout(regimen: twentyOneSeven, todayIndex: card.todayIndex, marks: card.marks)

        #expect(card.marks == [3: .missed, 9: .missed, 11: .late])
        #expect([2, 3, 9, 10, 11, 12].map(layout.state(at:)) == [.popped, .missed, .missed, .popped, .late, .sealed])
    }

    @Test func `A sugar pill left unlogged yesterday draws popped`() {
        let card = progress(twentyOneSeven, elapsed: 23)
        let layout = PackCardLayout(regimen: twentyOneSeven, todayIndex: card.todayIndex, marks: card.marks)

        #expect(card.marks == [:])
        #expect(layout.state(at: 22) == .popped)
    }

    @Test func `A finished pack keeps its missed pills`() {
        let finished = progress(twentyOneSeven, elapsed: 28, missed: [5], lateUntil: deadline, now: mondayEvening)

        #expect(finished.status == .finished)
        #expect(finished.marks == [5: .missed])
    }

    @Test func `The live day is ringed, and marked only once it is taken`() {
        let open = progress(twentyOneSeven, elapsed: 11)
        let taken = progress(twentyOneSeven, elapsed: 11, taken: true)

        #expect(open.todayIndex == 11)
        #expect(open.marks == [:])
        #expect(taken.marks == [11: .taken])
    }

    @Test func `A finished pack pops every tile and marks none`() {
        let finished = progress(twentyOneSeven, elapsed: 30, taken: true)

        #expect(finished.todayIndex == 28)
        #expect(finished.marks == [:])
    }

    @Test func `Day 1's weekday counts back from the live day`() {
        #expect(progress(twentyOneSeven, elapsed: 11).dayOneWeekday == 5)
        #expect(progress(twentyOneSeven, elapsed: 30).dayOneWeekday == 7)
        #expect(progress(twentyOneSeven, elapsed: 0).dayOneWeekday == 2)
    }
}

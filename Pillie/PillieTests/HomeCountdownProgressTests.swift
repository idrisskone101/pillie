//
//  HomeCountdownProgressTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HomeCountdownProgressTests {
    private let english = Locale(identifier: "en_US")
    private let reminderTime = "8:00 PM"

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, month: Int = 9, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// The live day is Monday 28 September 2026; it is 10 PM, past the 8 PM reminder.
    private func progress(
        _ method: RoutineDialMethod,
        day: Int,
        taken: Bool = false,
        late: Bool = false,
        missed: Set<Int> = [],
        caughtUp: [Int: Bool] = [:],
        now: Date? = nil
    ) -> HomeCountdownProgress {
        HomeCountdownProgress(
            method: method,
            cycleDay: day,
            isTodayTaken: taken,
            standing: late ? .late(until: date(29, hour: 20)) : .upcoming,
            misses: Dictionary(uniqueKeysWithValues: missed.map { ($0, .pending) })
                .merging(caughtUp.mapValues { .caughtUp(onLiveDay: $0) }) { _, caught in caught },
            reminderHour: 20,
            reminderMinute: 0,
            today: date(28),
            now: now ?? date(28, hour: 22),
            calendar: calendar
        )
    }

    private func card(_ progress: HomeCountdownProgress) -> [String?] {
        [
            progress.title(locale: english),
            progress.subtitle(locale: english),
            progress.headline(locale: english) ?? progress.dayCount(locale: english),
            progress.detail(locale: english),
            progress.chip(reminderTime: reminderTime, locale: english),
        ]
    }

    private func marks(_ progress: HomeCountdownProgress) -> [HomeCountdownProgress.Mark] {
        progress.milestones.map(\.mark)
    }

    private func labels(_ progress: HomeCountdownProgress) -> [String] {
        progress.milestones.map { progress.label($0.label, locale: english) }
    }

    private func focus(_ progress: HomeCountdownProgress) -> Int? {
        progress.milestones.first(where: \.isFocus)?.cycleDay
    }

    // MARK: Patch

    @Test func `Patch day 1 before anything is logged asks for patch 1`() {
        let putOn = progress(.patch, day: 1)

        #expect(putOn.state == .due(.putOnPatch))
        #expect(card(putOn) == ["Patch 1 of 3", "Day 1 of 28", "Today", "Put on patch 1", "Due 8:00 PM"])
        #expect(putOn.gauge == .due)
        #expect(putOn.object == .patch)
        #expect(marks(putOn) == [.current, .upcoming, .upcoming, .offDashed, .upcoming])
        #expect(labels(putOn) == ["Patch 1", "Patch 2", "Patch 3", "Off", "New pack"])
        #expect(putOn.lineSegments.isEmpty)
    }

    @Test func `A logged patch starts a seven day countdown from an empty gauge`() {
        let on = progress(.patch, day: 1, taken: true)

        #expect(on.state == .logged(.putOnPatch))
        #expect(card(on) == ["Patch 1 of 3", "On today", "7 days", "until you change it", "Oct 5 · 8:00 PM"])
        #expect(on.gauge == .logged)
        #expect(on.gaugeFraction == 0)
        #expect(on.nextTaskDate == date(5, month: 10, hour: 20))
        #expect(marks(on) == [.done, .upcoming, .upcoming, .offDashed, .upcoming])
    }

    @Test func `Patch day 10 counts down to the next change`() {
        let wearing = progress(.patch, day: 10)

        #expect(wearing.state == .wearing)
        #expect(card(wearing) == ["Patch 2 of 3", "Day 10 of 28", "5 days", "until you change it", "Oct 3 · 8:00 PM"])
        #expect(wearing.gauge == .progress(2.0 / 7.0, .method))
        #expect(marks(wearing) == [.done, .done, .upcoming, .offDashed, .upcoming])
        #expect(focus(wearing) == 8)
        #expect(wearing.todayTick?.position == 9.0 / 28.0)
        #expect(wearing.todayTick?.tint == .method)
        #expect(wearing.lineSegments == [.init(from: 0, to: 9.0 / 28.0, tint: .method)])
    }

    @Test func `One day left reads day, not days`() {
        #expect(card(progress(.patch, day: 14))[2] == "1 day")
    }

    @Test func `A change day shows the new patch in its sachet`() {
        let change = progress(.patch, day: 15)

        #expect(card(change) == ["Patch 3 of 3", "Day 15 of 28", "Today", "Put on patch 3", "Due 8:00 PM"])
        #expect(change.object == .sachet)
        #expect(marks(change) == [.done, .done, .current, .offDashed, .upcoming])
        #expect(change.lineSegments == [.init(from: 0, to: 14.0 / 28.0, tint: .method)])
    }

    @Test func `An untaken change past the reminder is late until the next reminder`() {
        let late = progress(.patch, day: 15, late: true)

        #expect(late.state == .late(.changePatch(3), endsTomorrow: true))
        #expect(card(late) == ["Patch 3 of 3", "Day 15 of 28", "Late", "Change to patch 3", "Until tomorrow 8:00 PM"])
        #expect(late.gauge == .late)
        #expect(marks(late) == [.done, .done, .late, .offDashed, .upcoming])

        let afterMidnight = progress(.patch, day: 15, late: true, now: date(29, hour: 1))
        #expect(afterMidnight.chip(reminderTime: reminderTime, locale: english) == "Until 8:00 PM")
    }

    @Test func `The day after an unlogged change reads missed`() {
        let missed = progress(.patch, day: 16, missed: [15])

        #expect(missed.state == .missed(.changePatch(3)))
        #expect(card(missed) == ["Patch 3 of 3", "Day 16 of 28", "Missed", "Change to patch 3 now", "Was due yesterday"])
        #expect(missed.gauge == .missed)
        #expect(missed.object == .patch)
        #expect(missed.isObjectFaded)
        #expect(marks(missed) == [.done, .done, .missed, .offDashed, .upcoming])
        #expect(focus(missed) == 15)
        #expect(missed.todayTick == nil)
        #expect(missed.lineSegments == [.init(from: 0, to: 14.0 / 28.0, tint: .method)])
    }

    @Test func `A missed change stays missed until the off day, with the due date after the first day`() {
        for day in 16...21 {
            #expect(progress(.patch, day: day, missed: [15]).state == .missed(.changePatch(3)), "day \(day)")
        }
        let later = progress(.patch, day: 18, missed: [15])
        #expect(card(later) == ["Patch 3 of 3", "Day 18 of 28", "Missed", "Change to patch 3 now", "Was due Sep 25"])
        #expect(marks(later) == [.done, .done, .missed, .offDashed, .upcoming])
        #expect(later.lineSegments == [.init(from: 0, to: 14.0 / 28.0, tint: .method)])

        let offDay = progress(.patch, day: 22, late: true, missed: [15])
        #expect(offDay.state == .late(.takeOffPatch, endsTomorrow: true))
        #expect(marks(offDay) == [.done, .done, .missed, .late, .upcoming])
    }

    @Test func `A change logged late reads logged that day and wearing after`() {
        let caughtUp = progress(.patch, day: 17, caughtUp: [15: true])
        #expect(caughtUp.state == .logged(.changePatch(3)))
        #expect(card(caughtUp) == ["Patch 3 of 3", "On today", "5 days", "until you take it off", "Oct 3 · 8:00 PM"])
        #expect(marks(caughtUp) == [.done, .done, .done, .offDashed, .upcoming])

        let nextDay = progress(.patch, day: 18, caughtUp: [15: false])
        #expect(nextDay.state == .wearing)
        #expect(card(nextDay) == ["Patch 3 of 3", "Day 18 of 28", "4 days", "until you take it off", "Oct 2 · 8:00 PM"])
    }

    @Test func `A missed ring removal stays missed through the ring-free week`() {
        for day in 23...28 {
            #expect(progress(.ring, day: day, missed: [22]).state == .missed(.ringOut), "day \(day)")
        }
        #expect(card(progress(.ring, day: 25, missed: [22])) == [
            "Ring in", "Day 25 of 28", "Missed", "Take your ring out now", "Was due Sep 25",
        ])
        #expect(progress(.ring, day: 29, late: true, missed: [22]).state == .late(.newRingIn, endsTomorrow: true))
    }

    @Test func `The catch-up window runs from the day after a task to the day before the next`() {
        #expect((1...30).map { CatchUpWindow.taskDay(on: $0, method: .patch) } == [
            nil, 1, 1, 1, 1, 1, 1,
            nil, 8, 8, 8, 8, 8, 8,
            nil, 15, 15, 15, 15, 15, 15,
            nil, 22, 22, 22, 22, 22, 22,
            nil, nil,
        ])
        #expect((1...30).map { CatchUpWindow.taskDay(on: $0, method: .ring) } == [nil] + Array(repeating: 1, count: 20)
            + [nil] + Array(repeating: 22, count: 6) + [nil, nil])
    }

    @Test func `The off day asks to take patch 3 off, then counts down to a new patch`() {
        #expect(card(progress(.patch, day: 22)) == ["Patch 3 of 3", "Day 22 of 28", "Today", "Take patch 3 off", "Due 8:00 PM"])
        #expect(progress(.patch, day: 22).object == .patch)

        let off = progress(.patch, day: 22, taken: true)
        #expect(card(off) == ["Patch-free week", "Off today", "7 days", "until a new patch", "Oct 5 · 8:00 PM"])
        #expect(off.object == .sachet)
        #expect(marks(off) == [.done, .done, .done, .done, .upcoming])
    }

    @Test func `A missed removal reads missed the next day`() {
        let missed = progress(.patch, day: 23, missed: [22])

        #expect(card(missed) == ["Patch 3 of 3", "Day 23 of 28", "Missed", "Take patch 3 off now", "Was due yesterday"])
        #expect(marks(missed) == [.done, .done, .done, .missed, .upcoming])
    }

    @Test func `The patch-free week counts down in sage`() {
        let free = progress(.patch, day: 25)

        #expect(free.state == .offWeek)
        #expect(card(free) == ["Patch-free week", "Day 25 of 28", "4 days", "until a new patch", "Oct 2 · 8:00 PM"])
        #expect(free.gauge == .progress(3.0 / 7.0, .sage))
        #expect(free.object == .sachet)
        #expect(!free.isObjectFaded)
        #expect(focus(free) == 22)
        #expect(free.todayTick?.tint == .sage)
        #expect(free.lineSegments == [
            .init(from: 0, to: 21.0 / 28.0, tint: .method),
            .init(from: 21.0 / 28.0, to: 24.0 / 28.0, tint: .sage),
        ])
    }

    @Test func `Past day 28 a patch waits for a new cycle and has no due time`() {
        let over = progress(.patch, day: 29)

        #expect(over.state == .newCycleDue(.putOnPatch))
        #expect(card(over) == ["New pack", "Day 29 · new cycle", "Today", "Put on patch 1", nil])
        #expect(over.object == .sachet)
        #expect(marks(over) == [.done, .done, .done, .done, .current])
        #expect(progress(.patch, day: 31, late: true).state == .newCycleDue(.putOnPatch))
    }

    // MARK: Ring

    @Test func `Ring day 1 asks for the ring and never dashes a milestone`() {
        let putIn = progress(.ring, day: 1)

        #expect(card(putIn) == ["New ring", "Day 1 of 28", "Today", "Put your ring in", "Due 8:00 PM"])
        #expect(putIn.object == .ring)
        #expect(marks(putIn) == [.current, .upcoming, .upcoming])
        #expect(labels(putIn) == ["In", "Out", "Back in"])
    }

    @Test func `A logged ring counts three weeks down`() {
        let inserted = progress(.ring, day: 1, taken: true)

        #expect(inserted.state == .logged(.ringIn))
        #expect(card(inserted) == ["Ring in", "In today", "21 days", "until it comes out", "Oct 19 · 8:00 PM"])
        #expect(inserted.gaugeFraction == 0)
    }

    @Test func `Ring day 10 fills nine twenty-firsts of the gauge`() {
        let wearing = progress(.ring, day: 10)

        #expect(card(wearing) == ["Ring in", "Day 10 of 28", "12 days", "until it comes out", "Oct 10 · 8:00 PM"])
        #expect(wearing.gauge == .progress(9.0 / 21.0, .method))
        #expect(marks(wearing) == [.done, .upcoming, .upcoming])
    }

    @Test func `A late ring removal keeps the ring in title`() {
        let late = progress(.ring, day: 22, late: true)

        #expect(card(late) == ["Ring in", "Day 22 of 28", "Late", "Take your ring out", "Until tomorrow 8:00 PM"])
        #expect(marks(late) == [.done, .late, .upcoming])
    }

    @Test func `Once the ring is out the art fades through the ring-free week`() {
        let out = progress(.ring, day: 22, taken: true)
        #expect(card(out) == ["Ring-free week", "Out today", "7 days", "until it goes back in", "Oct 5 · 8:00 PM"])
        #expect(out.isObjectFaded)

        let free = progress(.ring, day: 25)
        #expect(card(free) == ["Ring-free week", "Day 25 of 28", "4 days", "until it goes back in", "Oct 2 · 8:00 PM"])
        #expect(free.gauge == .progress(3.0 / 7.0, .sage))
        #expect(free.isObjectFaded)
    }

    @Test func `Day 29 keeps the reinsert loggable and late like any other task`() {
        let back = progress(.ring, day: 29, late: true)

        #expect(back.state == .late(.newRingIn, endsTomorrow: true))
        #expect(card(back) == ["New ring", "Day 29 · new cycle", "Late", "Put a new ring in", "Until tomorrow 8:00 PM"])
        #expect(marks(back) == [.done, .done, .late])
        #expect(back.lineSegments == [
            .init(from: 0, to: 21.0 / 28.0, tint: .method),
            .init(from: 21.0 / 28.0, to: 1, tint: .sage),
        ])
    }

    @Test func `After day 29 the ring waits for a new cycle instead of reading missed`() {
        let over = progress(.ring, day: 30, missed: [29])

        #expect(over.state == .newCycleDue(.newRingIn))
        #expect(card(over) == ["New ring", "Day 30 · new cycle", "Today", "Put a new ring in", nil])
        #expect(marks(over) == [.done, .done, .current])
    }

    @Test func `A missed insertion reads missed the next day`() {
        let missed = progress(.ring, day: 2, missed: [1])

        #expect(card(missed) == ["New ring", "Day 2 of 28", "Missed", "Put your ring in now", "Was due yesterday"])
        #expect(missed.isObjectFaded)
        #expect(marks(missed) == [.missed, .upcoming, .upcoming])
    }
}

struct MilestoneLabelPlacementTests {
    private let patchCenters: [CGFloat] = [12, 78.5, 145, 211.5, 278]

    @Test func `Short labels center on their nodes, with the end labels pinned to the tray edges`() {
        let frames = MilestoneLabelPlacement.frames(centers: patchCenters, widths: [38, 41, 40, 18, 52], trayWidth: 290)

        #expect(frames == [
            .init(x: 0, width: 38), .init(x: 58, width: 41), .init(x: 125, width: 40),
            .init(x: 202.5, width: 18), .init(x: 238, width: 52),
        ])
    }

    @Test func `Labels too wide for the tray share one cap and never overlap`() {
        let frames = MilestoneLabelPlacement.frames(centers: patchCenters, widths: [86, 86, 86, 40, 60], trayWidth: 290)

        #expect(frames == [
            .init(x: 0, width: 56), .init(x: 62, width: 56), .init(x: 124, width: 56),
            .init(x: 188, width: 40), .init(x: 234, width: 56),
        ])
    }

    @Test func `A long last label pushes its neighbour inward instead of leaving the tray`() {
        let frames = MilestoneLabelPlacement.frames(centers: [12, 211.5, 278], widths: [30, 50, 101], trayWidth: 290)

        #expect(frames == [.init(x: 0, width: 30), .init(x: 133, width: 50), .init(x: 189, width: 101)])
    }
}

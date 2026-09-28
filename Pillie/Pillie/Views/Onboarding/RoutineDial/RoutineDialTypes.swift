//
//  RoutineDialTypes.swift
//  Pillie
//

import Foundation

struct RoutineDialSelection: Equatable {
    let method: RoutineDialMethod
    private(set) var cycleDay: Int
    private(set) var answer: TodayPillPick.Answer?

    static let patchSegmentCount = RoutineDialDay.patchCount + 1

    init(method: RoutineDialMethod, cycleDay: Int = 1) {
        self.method = method
        self.cycleDay = min(max(cycleDay, 1), RoutineDialDay.cycleLength)
    }

    init(restoring pick: RoutineDialPick) {
        method = pick.method
        cycleDay = pick.cycleDay
        answer = pick.answer
    }

    var day: RoutineDialDay {
        RoutineDialDay.day(cycleDay, method: method)
    }

    var asksQuestion: Bool {
        day.task != nil
    }

    var pick: RoutineDialPick? {
        RoutineDialPick(method: method, cycleDay: cycleDay, answer: answer)
    }

    var patchSegment: Int {
        (cycleDay - 1) / RoutineDialDay.daysPerPatch
    }

    var dialCount: Int {
        switch method {
        case .patch: RoutineDialDay.daysPerPatch
        case .ring: RoutineDialDay.cycleLength
        }
    }

    var dialDay: Int {
        switch method {
        case .patch: (cycleDay - 1) % RoutineDialDay.daysPerPatch + 1
        case .ring: cycleDay
        }
    }

    mutating func selectSegment(_ segment: Int) {
        guard method == .patch, (0..<Self.patchSegmentCount).contains(segment) else { return }
        move(to: segment * RoutineDialDay.daysPerPatch + dialDay)
    }

    mutating func selectDialDay(_ day: Int) {
        guard (1...dialCount).contains(day) else { return }
        switch method {
        case .patch: move(to: patchSegment * RoutineDialDay.daysPerPatch + day)
        case .ring: move(to: day)
        }
    }

    mutating func record(_ answer: TodayPillPick.Answer) {
        guard asksQuestion else { return }
        self.answer = answer
    }

    private mutating func move(to cycleDay: Int) {
        guard cycleDay != self.cycleDay else { return }
        self.cycleDay = cycleDay
        answer = nil
    }
}

struct RoutineDialCopy {
    enum Status: Equatable {
        case logged(String)
        case notYet(String)
    }

    struct ResultRow: Equatable {
        let title: String
        let detail: String
    }

    let selection: RoutineDialSelection
    var today: Date = Calendar.current.startOfDay(for: PillieClock.now)
    var calendar: Calendar = .current
    var locale: Locale = .current

    private var method: RoutineDialMethod { selection.method }
    private var day: RoutineDialDay { selection.day }

    var title: String {
        switch method {
        case .patch:
            string(day.phase == .free ? "onboarding.dial.patch.free_title" : "onboarding.dial.patch.title")
        case .ring:
            string("onboarding.dial.ring.title")
        }
    }

    var subtitle: String {
        string(method == .patch ? "onboarding.dial.patch.subtitle" : "onboarding.dial.ring.subtitle")
    }

    var hint: String {
        string(method == .patch ? "onboarding.dial.patch.hint" : "onboarding.dial.ring.hint")
    }

    var segmentTitles: [String] {
        (1...RoutineDialDay.patchCount).map { formatted("onboarding.dial.patch.segment", $0) }
            + [string("onboarding.dial.patch.off_week")]
    }

    var dayLabel: String {
        formatted("onboarding.dial.day", selection.dialDay)
    }

    var centerSubtitle: String {
        switch (method, day.task, day.phase) {
        case (.patch, .putOn, _):
            return formatted("onboarding.dial.patch.goes_on_today", patchNumber)
        case (.patch, .takeOff, _):
            return string("onboarding.dial.patch.comes_off_today")
        case (.ring, .putOn, _):
            return string("onboarding.dial.ring.goes_in_today")
        case (.ring, .takeOff, _):
            return string("onboarding.dial.ring.comes_out_today")
        case (.patch, nil, .wearing):
            let patchStart = (patchNumber - 1) * RoutineDialDay.daysPerPatch + 1
            return formatted("onboarding.dial.patch.on_since", weekday(patchStart))
        case (.patch, nil, .free):
            return formatted("onboarding.dial.patch.off_since", weekday(Self.removeDay))
        case (.ring, nil, .wearing):
            return formatted("onboarding.dial.ring.in_since", shortDate(1))
        case (.ring, nil, .free):
            return formatted("onboarding.dial.ring.out_since", shortDate(Self.removeDay))
        }
    }

    var resultRow: ResultRow? {
        guard day.task == nil else { return nil }
        switch (method, day.phase) {
        case (.patch, .wearing) where patchNumber < RoutineDialDay.patchCount:
            let change = patchNumber * RoutineDialDay.daysPerPatch + 1
            return ResultRow(
                title: formatted("onboarding.dial.patch.next_change", longDate(change)),
                detail: formatted("onboarding.dial.patch.next_change_detail", weekday(change))
            )
        case (.patch, .wearing):
            return ResultRow(
                title: formatted("onboarding.dial.patch.comes_off", longDate(Self.removeDay)),
                detail: string("onboarding.dial.patch.comes_off_detail")
            )
        case (.patch, .free):
            return ResultRow(
                title: formatted("onboarding.dial.patch.goes_on", longDate(Self.nextCycleDay)),
                detail: string("onboarding.dial.patch.goes_on_detail")
            )
        case (.ring, .wearing):
            return ResultRow(
                title: formatted("onboarding.dial.ring.comes_out", longDate(Self.removeDay)),
                detail: formatted("onboarding.dial.ring.back_in", longDate(Self.nextCycleDay))
            )
        case (.ring, .free):
            return ResultRow(
                title: formatted("onboarding.dial.ring.goes_in", longDate(Self.nextCycleDay)),
                detail: formatted("onboarding.dial.ring.free_day", day.cycleDay - RoutineDialDay.wearingDays)
            )
        }
    }

    var question: String? {
        switch (method, day.task) {
        case (_, nil): nil
        case (.patch, .putOn): formatted("onboarding.dial.patch.question_on", patchNumber)
        case (.patch, .takeOff): string("onboarding.dial.patch.question_off")
        case (.ring, .putOn): string("onboarding.dial.ring.question_in")
        case (.ring, .takeOff): string("onboarding.dial.ring.question_out")
        }
    }

    var yesTitle: String {
        switch (method, day.task) {
        case (.patch, .takeOff): string("onboarding.dial.patch.yes_off")
        case (.patch, _): string("onboarding.dial.patch.yes_on")
        case (.ring, .takeOff): string("onboarding.dial.ring.yes_out")
        case (.ring, _): string("onboarding.dial.ring.yes_in")
        }
    }

    var notYetTitle: String {
        string("onboarding.today_pill.not_yet")
    }

    var status: Status? {
        switch selection.answer {
        case nil:
            return nil
        case .notYet:
            return .notYet(string("onboarding.dial.not_yet_status"))
        case .taken:
            switch (method, day.task) {
            case (.patch, .putOn) where patchNumber < RoutineDialDay.patchCount:
                let change = patchNumber * RoutineDialDay.daysPerPatch + 1
                return .logged(formatted("onboarding.dial.logged.next_change", longDate(change)))
            case (.patch, .putOn):
                return .logged(formatted("onboarding.dial.logged.patch_comes_off", longDate(Self.removeDay)))
            case (.patch, .takeOff):
                return .logged(formatted("onboarding.dial.logged.patch_goes_on", longDate(Self.nextCycleDay)))
            case (.ring, .putOn):
                return .logged(formatted("onboarding.dial.logged.ring_comes_out", longDate(Self.removeDay)))
            case (.ring, .takeOff):
                return .logged(formatted("onboarding.dial.logged.ring_goes_in", longDate(Self.nextCycleDay)))
            case (_, nil):
                return nil
            }
        }
    }

    var accessibilityLabel: String {
        string("onboarding.dial.a11y.label")
    }

    var accessibilityHint: String {
        string("onboarding.dial.a11y.hint")
    }

    private static let removeDay = RoutineDialDay.wearingDays + 1
    private static let nextCycleDay = RoutineDialDay.cycleLength + 1

    private var patchNumber: Int {
        day.patchNumber ?? RoutineDialDay.patchCount
    }

    private func date(ofCycleDay cycleDay: Int) -> Date {
        calendar.date(byAdding: .day, value: cycleDay - day.cycleDay, to: today) ?? today
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    private func longDate(_ cycleDay: Int) -> String {
        date(ofCycleDay: cycleDay).formatted(style.weekday(.wide).month(.abbreviated).day())
    }

    private func shortDate(_ cycleDay: Int) -> String {
        date(ofCycleDay: cycleDay).formatted(style.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func weekday(_ cycleDay: Int) -> String {
        date(ofCycleDay: cycleDay).formatted(style.weekday(.wide))
    }

    private func string(_ key: String) -> String {
        PillieLocalization.string(key, locale: locale)
    }

    private func formatted(_ key: String, _ argument: CVarArg) -> String {
        PillieLocalization.formatted(key, locale: locale, arguments: argument)
    }
}

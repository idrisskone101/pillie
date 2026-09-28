//
//  HomeCountdownProgress.swift
//  Pillie
//

import Foundation

/// Where a patch or ring cycle stands today: what Home's countdown card draws and says.
/// The day table is `RoutineDialDay`; late comes from `DoseStanding`; missed from the store's day status.
struct HomeCountdownProgress: Hashable, Sendable {
    enum Task: Hashable, Sendable {
        case putOnPatch
        case changePatch(Int)
        case takeOffPatch
        case ringIn
        case ringOut
        case newRingIn
    }

    enum State: Hashable, Sendable {
        case due(Task)
        case logged(Task)
        case wearing
        case late(Task, endsTomorrow: Bool)
        case missed(Task)
        case offWeek
        /// The cycle is over and nothing can be logged until a new one starts (`PillStore.isRefillDue`).
        case newCycleDue(Task)
    }

    enum Tint: Hashable, Sendable {
        case method
        case sage
        case amber
    }

    enum Gauge: Hashable, Sendable {
        case due
        case late
        case missed
        case logged
        case progress(Double, Tint)
    }

    enum Object: Hashable, Sendable {
        case patch
        case sachet
        case ring
    }

    enum Mark: Hashable, Sendable {
        case done
        case current
        case late
        case missed
        case upcoming
        case offDashed
    }

    struct Milestone: Hashable, Sendable, Identifiable {
        enum Label: Hashable, Sendable {
            case patch(Int)
            case off
            case newPack
            case ringIn
            case ringOut
            case backIn
        }

        let cycleDay: Int
        let label: Label
        let mark: Mark
        /// The milestone that owns today; its label is bold.
        let isFocus: Bool
        let isPast: Bool

        var id: Int { cycleDay }
        var position: Double { HomeCountdownProgress.position(ofCycleDay: cycleDay) }
    }

    struct LineSegment: Hashable, Sendable {
        let from: Double
        let to: Double
        let tint: Tint
    }

    static let cycleLength = RoutineDialDay.cycleLength
    private static let freeWeekStart = RoutineDialDay.wearingDays + 1

    let method: RoutineDialMethod
    /// Days since the cycle's day 1, plus one. 29 or more once the cycle is over.
    let cycleDay: Int
    let state: State
    /// Days until the next task; 0 while a task is today's.
    let daysLeft: Int
    let nextTaskDate: Date?
    let gaugeFraction: Double
    let milestones: [Milestone]

    private let missedTaskDays: Set<Int>
    private let today: Date
    private let calendar: Calendar

    init(
        method: RoutineDialMethod,
        cycleDay: Int,
        isTodayTaken: Bool,
        standing: DoseStanding?,
        missedTaskDays: Set<Int> = [],
        reminderHour: Int,
        reminderMinute: Int,
        today: Date,
        now: Date,
        calendar: Calendar
    ) {
        let cycleDay = max(1, cycleDay)
        self.method = method
        self.cycleDay = cycleDay
        self.missedTaskDays = missedTaskDays
        self.today = calendar.startOfDay(for: today)
        self.calendar = calendar

        let state = Self.state(
            method: method,
            cycleDay: cycleDay,
            isTodayTaken: isTodayTaken,
            standing: standing,
            missedTaskDays: missedTaskDays,
            now: now,
            calendar: calendar
        )
        self.state = state

        let taskDays = Self.taskDays(for: method)
        let hasOpenTask: Bool = switch state {
        case .due, .late, .missed, .newCycleDue: true
        case .logged, .wearing, .offWeek: false
        }
        if hasOpenTask {
            daysLeft = 0
            nextTaskDate = nil
            gaugeFraction = 1
        } else {
            let next = taskDays.first { $0 > cycleDay } ?? taskDays[taskDays.count - 1]
            let previous = taskDays.last { $0 <= cycleDay } ?? 1
            let segment = max(1, next - previous)
            daysLeft = next - cycleDay
            gaugeFraction = Double(segment - daysLeft) / Double(segment)
            nextTaskDate = calendar.date(byAdding: .day, value: daysLeft, to: self.today).flatMap {
                calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: $0)
            }
        }

        milestones = Self.milestones(
            method: method,
            cycleDay: cycleDay,
            state: state,
            missedTaskDays: missedTaskDays
        )
    }

    // MARK: Drawing

    var gauge: Gauge {
        switch state {
        case .due, .newCycleDue: .due
        case .late: .late
        case .missed: .missed
        case .logged: .logged
        case .wearing: .progress(gaugeFraction, .method)
        case .offWeek: .progress(gaugeFraction, .sage)
        }
    }

    var object: Object {
        guard method == .patch else { return .ring }
        switch state {
        case .due(.changePatch), .late(.changePatch, _), .logged(.takeOffPatch), .offWeek, .newCycleDue:
            return .sachet
        default:
            return .patch
        }
    }

    /// The art fades while it is off the body or overdue.
    var isObjectFaded: Bool {
        switch state {
        case .missed: true
        case .offWeek, .logged(.ringOut): method == .ring
        default: false
        }
    }

    /// Today's tick on the track, between milestones only.
    var todayTick: (position: Double, tint: Tint)? {
        switch state {
        case .wearing: (Self.position(ofCycleDay: cycleDay), .method)
        case .offWeek: (Self.position(ofCycleDay: cycleDay), .sage)
        default: nil
        }
    }

    /// The filled track: method color through the wearing weeks, sage through the free week.
    var lineSegments: [LineSegment] {
        let end: Double = if case .missed = state,
                             let focus = milestones.first(where: \.isFocus) {
            focus.position
        } else {
            Self.position(ofCycleDay: cycleDay)
        }
        let freeWeek = Self.position(ofCycleDay: Self.freeWeekStart)
        var segments: [LineSegment] = []
        if end > 0 {
            segments.append(LineSegment(from: 0, to: min(end, freeWeek), tint: .method))
        }
        if end > freeWeek {
            segments.append(LineSegment(from: freeWeek, to: end, tint: .sage))
        }
        return segments
    }

    static func position(ofCycleDay day: Int) -> Double {
        min(1, Double(max(0, day - 1)) / Double(cycleLength))
    }

    // MARK: Copy

    func title(locale: Locale) -> String {
        let key: String
        var patchNumber: Int?
        switch titleKind {
        case .patch(let number):
            key = "home.countdown.title.patch"
            patchNumber = number
        case .patchFree: key = "home.countdown.title.patch_free"
        case .newPack: key = "home.countdown.title.new_pack"
        case .ringIn: key = "home.countdown.title.ring_in"
        case .ringFree: key = "home.countdown.title.ring_free"
        case .newRing: key = "home.countdown.title.new_ring"
        }
        guard let patchNumber else { return PillieLocalization.string(key, locale: locale) }
        return PillieLocalization.formatted(key, locale: locale, arguments: patchNumber, RoutineDialDay.patchCount)
    }

    func subtitle(locale: Locale) -> String {
        if case .logged(let task) = state {
            let key = switch task {
            case .putOnPatch, .changePatch: "home.countdown.subtitle.on_today"
            case .takeOffPatch: "home.countdown.subtitle.off_today"
            case .ringIn, .newRingIn: "home.countdown.subtitle.in_today"
            case .ringOut: "home.countdown.subtitle.out_today"
            }
            return PillieLocalization.string(key, locale: locale)
        }
        if cycleDay > Self.cycleLength {
            return PillieLocalization.formatted("home.countdown.subtitle.new_cycle", locale: locale, arguments: cycleDay)
        }
        return SettingsPresentation.cycleDay(day: cycleDay, total: Self.cycleLength, locale: locale)
    }

    /// "Today", "Late" or "Missed" while a task is open; nil when the card counts days.
    func headline(locale: Locale) -> String? {
        let key: String? = switch state {
        case .due, .newCycleDue: "home.countdown.today"
        case .late: "home.countdown.late"
        case .missed: "home.countdown.missed"
        case .logged, .wearing, .offWeek: nil
        }
        return key.map { PillieLocalization.string($0, locale: locale) }
    }

    /// The day count with its unit, "5 days".
    func dayCount(locale: Locale) -> String {
        PillieLocalization.formatted("home.countdown.days", locale: locale, arguments: daysLeft)
    }

    func detail(locale: Locale) -> String {
        switch state {
        case .due(let task), .late(let task, _), .newCycleDue(let task):
            return taskPhrase(task, suffix: "", locale: locale)
        case .missed(let task):
            return taskPhrase(task, suffix: ".now", locale: locale)
        case .logged, .wearing, .offWeek:
            return PillieLocalization.string(untilKey, locale: locale)
        }
    }

    func chip(reminderTime: String, locale: Locale) -> String? {
        switch state {
        case .due:
            return PillieLocalization.formatted("home.countdown.chip.due", locale: locale, arguments: reminderTime)
        case .late(_, let endsTomorrow):
            let key = endsTomorrow ? "home.countdown.chip.until_tomorrow" : "home.countdown.chip.until_today"
            return PillieLocalization.formatted(key, locale: locale, arguments: reminderTime)
        case .missed:
            return PillieLocalization.string("home.countdown.chip.missed_yesterday", locale: locale)
        case .newCycleDue:
            return nil
        case .logged, .wearing, .offWeek:
            guard let nextTaskDate else { return nil }
            let date = nextTaskDate.formatted(
                Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                    .month(.abbreviated)
                    .day()
            )
            return PillieLocalization.formatted("home.countdown.chip.when", locale: locale, arguments: date, reminderTime)
        }
    }

    func label(_ label: Milestone.Label, locale: Locale) -> String {
        switch label {
        case .patch(let number):
            PillieLocalization.formatted("home.countdown.milestone.patch", locale: locale, arguments: number)
        case .off: PillieLocalization.string("home.countdown.milestone.off", locale: locale)
        case .newPack: PillieLocalization.string("home.countdown.milestone.new_pack", locale: locale)
        case .ringIn: PillieLocalization.string("home.countdown.milestone.in", locale: locale)
        case .ringOut: PillieLocalization.string("home.countdown.milestone.out", locale: locale)
        case .backIn: PillieLocalization.string("home.countdown.milestone.back_in", locale: locale)
        }
    }

    private func taskPhrase(_ task: Task, suffix: String, locale: Locale) -> String {
        switch task {
        case .putOnPatch:
            PillieLocalization.formatted("home.countdown.task.put_on_patch\(suffix)", locale: locale, arguments: 1)
        case .changePatch(let number):
            PillieLocalization.formatted(
                "home.countdown.task.\(Self.isLateOrMissed(state) ? "change_patch" : "put_on_patch")\(suffix)",
                locale: locale,
                arguments: number
            )
        case .takeOffPatch:
            PillieLocalization.formatted(
                "home.countdown.task.take_off_patch\(suffix)", locale: locale, arguments: RoutineDialDay.patchCount
            )
        case .ringIn: PillieLocalization.string("home.countdown.task.ring_in\(suffix)", locale: locale)
        case .ringOut: PillieLocalization.string("home.countdown.task.ring_out\(suffix)", locale: locale)
        case .newRingIn: PillieLocalization.string("home.countdown.task.new_ring\(suffix)", locale: locale)
        }
    }

    private var untilKey: String {
        let next = cycleDay + daysLeft
        switch method {
        case .patch:
            if next > Self.cycleLength { return "home.countdown.until.new_patch" }
            return next > RoutineDialDay.wearingDays ? "home.countdown.until.take_off" : "home.countdown.until.change"
        case .ring:
            return next > Self.cycleLength ? "home.countdown.until.ring_in" : "home.countdown.until.ring_out"
        }
    }

    private static func isLateOrMissed(_ state: State) -> Bool {
        switch state {
        case .late, .missed: true
        default: false
        }
    }

    // MARK: Header

    private enum TitleKind {
        case patch(Int)
        case patchFree
        case newPack
        case ringIn
        case ringFree
        case newRing
    }

    private var titleKind: TitleKind {
        switch state {
        case .due(let task), .late(let task, _), .missed(let task), .newCycleDue(let task):
            return openTaskTitle(task)
        case .logged(let task):
            switch task {
            case .putOnPatch: return .patch(1)
            case .changePatch(let number): return .patch(number)
            case .takeOffPatch: return .patchFree
            case .ringIn, .newRingIn: return .ringIn
            case .ringOut: return .ringFree
            }
        case .wearing:
            let day = RoutineDialDay.day(min(cycleDay, Self.cycleLength), method: method)
            return method == .patch ? .patch(day.patchNumber ?? 1) : .ringIn
        case .offWeek:
            return method == .patch ? .patchFree : .ringFree
        }
    }

    /// What the card is called before the task is logged: the patch or ring it is about.
    private func openTaskTitle(_ task: Task) -> TitleKind {
        switch task {
        case .putOnPatch: cycleDay > Self.cycleLength ? .newPack : .patch(1)
        case .changePatch(let number): .patch(number)
        case .takeOffPatch: .patch(RoutineDialDay.patchCount)
        case .ringIn, .newRingIn: .newRing
        case .ringOut: .ringIn
        }
    }

    // MARK: Rules

    static func taskDays(for method: RoutineDialMethod) -> [Int] {
        (1...cycleLength).filter { RoutineDialDay.day($0, method: method).task != nil } + [cycleLength + 1]
    }

    static func task(onCycleDay day: Int, method: RoutineDialMethod) -> Task? {
        guard day <= cycleLength else { return method == .patch ? .putOnPatch : .newRingIn }
        let dialDay = RoutineDialDay.day(day, method: method)
        switch (method, dialDay.task) {
        case (_, nil): return nil
        case (.patch, .putOn): return day == 1 ? .putOnPatch : .changePatch(dialDay.patchNumber ?? 1)
        case (.patch, .takeOff): return .takeOffPatch
        case (.ring, .putOn): return .ringIn
        case (.ring, .takeOff): return .ringOut
        }
    }

    private static func state(
        method: RoutineDialMethod,
        cycleDay: Int,
        isTodayTaken: Bool,
        standing: DoseStanding?,
        missedTaskDays: Set<Int>,
        now: Date,
        calendar: Calendar
    ) -> State {
        // DoseScheduleEngine keeps the ring's day 29 reinsert loggable; every other day past 28 waits for a new cycle.
        let reinsertDay = cycleLength + 1
        if cycleDay > cycleLength, method == .patch || cycleDay > reinsertDay {
            return .newCycleDue(method == .patch ? .putOnPatch : .newRingIn)
        }
        let todayTask = task(onCycleDay: cycleDay, method: method)
        if let todayTask, isTodayTaken { return .logged(todayTask) }
        if missedTaskDays.contains(cycleDay - 1), let missed = task(onCycleDay: cycleDay - 1, method: method) {
            return .missed(missed)
        }
        if let todayTask {
            if case .late(let until)? = standing {
                return .late(todayTask, endsTomorrow: !calendar.isDate(until, inSameDayAs: now))
            }
            return .due(todayTask)
        }
        return cycleDay > RoutineDialDay.wearingDays ? .offWeek : .wearing
    }

    private static func milestones(
        method: RoutineDialMethod,
        cycleDay: Int,
        state: State,
        missedTaskDays: Set<Int>
    ) -> [Milestone] {
        let days = taskDays(for: method)
        let focusDay: Int = if case .missed = state {
            cycleDay - 1
        } else {
            days.last { $0 <= cycleDay } ?? 1
        }
        return days.map { day in
            let mark: Mark
            if day == focusDay {
                mark = switch state {
                case .due, .newCycleDue: .current
                case .late: .late
                case .missed: .missed
                case .logged, .wearing, .offWeek: missedTaskDays.contains(day) ? .missed : .done
                }
            } else if day < focusDay {
                mark = missedTaskDays.contains(day) ? .missed : .done
            } else {
                mark = method == .patch && day == freeWeekStart ? .offDashed : .upcoming
            }
            return Milestone(
                cycleDay: day,
                label: label(forTaskDay: day, method: method),
                mark: mark,
                isFocus: day == focusDay,
                isPast: day < focusDay
            )
        }
    }

    private static func label(forTaskDay day: Int, method: RoutineDialMethod) -> Milestone.Label {
        switch (method, task(onCycleDay: day, method: method)) {
        case (.patch, .changePatch(let number)?): .patch(number)
        case (.patch, .takeOffPatch?): .off
        case (.patch, _): day == 1 ? .patch(1) : .newPack
        case (.ring, .ringOut?): .ringOut
        case (.ring, _): day == 1 ? .ringIn : .backIn
        }
    }
}

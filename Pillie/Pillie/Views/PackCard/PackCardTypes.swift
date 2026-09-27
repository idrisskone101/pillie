//
//  PackCardTypes.swift
//  Pillie
//

import Foundation

/// What the caller asserts about one day, beyond its position relative to today.
enum PackTileMark: Hashable, Sendable {
    case taken
    case late
    case missed
}

/// What one tile shows. The view draws `PackDay.Kind` x `PackTileState`.
enum PackTileState: Hashable, Sendable {
    case sealed
    case popped
    case today
    case logged
    case late
    case missed

    var isPillOut: Bool {
        switch self {
        case .popped, .logged: return true
        case .sealed, .today, .late, .missed: return false
        }
    }
}

enum PackTrackTone: Hashable, Sendable {
    case passed
    case viewed
    case upcoming
    case upcomingBreak
}

enum PackPageLabel: Hashable, Sendable {
    case weeks(first: Int, last: Int, total: Int)
    case week(Int, total: Int)
}

struct PackCardLayout: Hashable, Sendable {
    static let daysPerWeek = 7
    static let weeksPerPage = 4
    static let daysPerPage = daysPerWeek * weeksPerPage

    let regimen: PackRegimen
    /// 0-based. nil is a sealed pack with nothing ringed; `>= totalDays` is a finished pack.
    let todayIndex: Int?
    var marks: [Int: PackTileMark] = [:]

    var totalDays: Int { regimen.totalDays }

    var pageCount: Int {
        (regimen.weekCount + Self.weeksPerPage - 1) / Self.weeksPerPage
    }

    var showsPager: Bool { totalDays > Self.daysPerPage }

    var todayPage: Int {
        guard let todayIndex else { return 0 }
        return min(max(todayIndex, 0) / Self.daysPerPage, pageCount - 1)
    }

    var states: [PackTileState] {
        (0..<totalDays).map(state(at:))
    }

    func state(at index: Int) -> PackTileState {
        // Nothing is taken on a pill-free day, so its marks carry no meaning.
        if regimen.day(atIndex: index).kind != .noPill, let mark = marks[index] {
            switch mark {
            case .taken: return index == todayIndex ? .logged : .popped
            case .late: return .late
            case .missed: return .missed
            }
        }
        guard let todayIndex else { return .sealed }
        if index < todayIndex { return .popped }
        if index == todayIndex { return .today }
        return .sealed
    }

    func dayIndices(onPage page: Int) -> Range<Int> {
        let start = page * Self.daysPerPage
        return start..<min(start + Self.daysPerPage, totalDays)
    }

    /// Rows of day indices; the pack's last row is short when it does not fill a week.
    func rows(onPage page: Int) -> [Range<Int>] {
        let days = dayIndices(onPage: page)
        return stride(from: days.lowerBound, to: days.upperBound, by: Self.daysPerWeek).map { start in
            start..<min(start + Self.daysPerWeek, days.upperBound)
        }
    }

    func pageLabel(forPage page: Int) -> PackPageLabel {
        let firstWeek = page * Self.weeksPerPage + 1
        let lastWeek = min(firstWeek + Self.weeksPerPage - 1, regimen.weekCount)
        if firstWeek == lastWeek {
            return .week(firstWeek, total: regimen.weekCount)
        }
        return .weeks(first: firstWeek, last: lastWeek, total: regimen.weekCount)
    }

    /// One tone per week, relative to the page being viewed.
    func trackTones(viewedPage: Int) -> [PackTrackTone] {
        (0..<regimen.weekCount).map { week in
            let page = week / Self.weeksPerPage
            if page < viewedPage { return .passed }
            if page == viewedPage { return .viewed }
            let days = (week * Self.daysPerWeek)..<min((week + 1) * Self.daysPerWeek, totalDays)
            let hasBreak = days.contains { regimen.day(atIndex: $0).kind != .active }
            return hasBreak ? .upcomingBreak : .upcoming
        }
    }
}

/// The stop-motion timeline that walks displayed tile states to a new target.
enum PackPopSequence {
    /// Gap between neighbouring tiles in a cascade. Callers time their haptic ticks to it.
    static let popStagger: Duration = .milliseconds(45)
    static let crunchHold: Duration = .milliseconds(90)

    enum Change: Hashable, Sendable {
        case crunch
        case settle(PackTileState)
    }

    struct Step: Hashable, Sendable {
        let at: Duration
        let index: Int
        let change: Change
    }

    static func steps(
        from displayed: [PackTileState],
        to target: [PackTileState],
        regimen: PackRegimen
    ) -> [Step] {
        let changed = displayed.indices.filter { displayed[$0] != target[$0] }
        let pops = changed.filter { !displayed[$0].isPillOut && target[$0].isPillOut }
        let reseals = changed.filter { displayed[$0].isPillOut && !target[$0].isPillOut }
        let instant = changed.filter { !pops.contains($0) && !reseals.contains($0) }

        var steps = instant.map { Step(at: .zero, index: $0, change: .settle(target[$0])) }
        for (order, index) in pops.enumerated() {
            let start = popStagger * order
            if regimen.day(atIndex: index).kind == .active {
                steps.append(Step(at: start, index: index, change: .crunch))
                steps.append(Step(at: start + crunchHold, index: index, change: .settle(target[index])))
            } else {
                steps.append(Step(at: start, index: index, change: .settle(target[index])))
            }
        }
        for (order, index) in reseals.reversed().enumerated() {
            steps.append(Step(at: popStagger * order, index: index, change: .settle(target[index])))
        }
        return steps.enumerated()
            .sorted { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }
            .map(\.element)
    }
}

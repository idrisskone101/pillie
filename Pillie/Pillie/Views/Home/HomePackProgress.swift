//
//  HomePackProgress.swift
//  Pillie
//

import Foundation

/// Where the live day sits in a pill pack: what Home's pack card rings and what its header says.
struct HomePackProgress: Hashable, Sendable {
    enum Status: Hashable, Sendable {
        case finished
        case taken
        case breakDay
        case sugarPill(PackDay)
        case firstPill
        case lastHormonePill(PackRegimen.BreakKind)
        case pill
    }

    let regimen: PackRegimen
    /// Days since the pack's day 1: negative before it, `totalDays` or more once the pack is finished.
    let elapsedDays: Int
    let isTodayTaken: Bool
    /// Calendar weekday (1 = Sunday) of the pack's day 1.
    let dayOneWeekday: Int

    init(regimen: PackRegimen, elapsedDays: Int, isTodayTaken: Bool, today: Date, calendar: Calendar) {
        self.regimen = regimen
        self.elapsedDays = elapsedDays
        self.isTodayTaken = isTodayTaken
        let dayOne = calendar.date(byAdding: .day, value: -elapsedDays, to: calendar.startOfDay(for: today)) ?? today
        dayOneWeekday = calendar.component(.weekday, from: dayOne)
    }

    var isFinished: Bool { elapsedDays >= regimen.totalDays }

    /// nil while the live day precedes the pack; `totalDays` once it is finished, so every tile is out.
    var todayIndex: Int? {
        elapsedDays < 0 ? nil : min(elapsedDays, regimen.totalDays)
    }

    var marks: [Int: PackTileMark] {
        guard isTodayTaken, !isFinished, let todayIndex else { return [:] }
        return [todayIndex: .taken]
    }

    var status: Status {
        if isFinished { return .finished }
        let day = regimen.day(atIndex: max(elapsedDays, 0))
        if isTodayTaken { return .taken }
        switch day.kind {
        case .noPill: return .breakDay
        case .sugarPill: return .sugarPill(day)
        case .active:
            if day.number == 1 { return .firstPill }
            if day.number == regimen.activeDays, regimen.breakDays > 0 {
                return .lastHormonePill(regimen.breakKind)
            }
            return .pill
        }
    }

    func title(locale: Locale) -> String {
        if isFinished {
            return PillieLocalization.string("home.pack.title.finished", locale: locale)
        }
        let day = regimen.day(atIndex: max(elapsedDays, 0))
        switch day.kind {
        case .active:
            return PillieLocalization.formatted(
                "home.pack.title.pill", locale: locale, arguments: day.number, regimen.totalDays
            )
        case .sugarPill:
            return PillieLocalization.formatted(
                "home.pack.title.sugar_pill", locale: locale,
                arguments: day.number - regimen.activeDays, regimen.breakDays
            )
        case .noPill:
            return PillieLocalization.formatted(
                "home.pack.title.break_day", locale: locale,
                arguments: day.number - regimen.activeDays, regimen.breakDays
            )
        }
    }

    func subtitle(reminderTime: String, locale: Locale) -> String {
        switch status {
        case .finished:
            return PillieLocalization.string("home.pack.subtitle.finished", locale: locale)
        case .taken:
            return PillieLocalization.string("home.pack.subtitle.taken", locale: locale)
        case .breakDay:
            return PillieLocalization.formatted(
                "home.pack.subtitle.break_day", locale: locale, arguments: nextPackWeekdayName(locale: locale)
            )
        case .sugarPill(let day):
            return PillieLocalization.formatted(
                "home.pack.subtitle.sugar_pill", locale: locale,
                arguments: day.number, regimen.totalDays, nextPackWeekdayName(locale: locale)
            )
        case .firstPill:
            return PillieLocalization.formatted(
                "home.pack.subtitle.first_pill", locale: locale, arguments: regimenName(locale: locale)
            )
        case .lastHormonePill(let breakKind):
            let key = breakKind == .sugarPills
                ? "home.pack.subtitle.last_pill_sugar"
                : "home.pack.subtitle.last_pill_break"
            return PillieLocalization.string(key, locale: locale)
        case .pill:
            return PillieLocalization.formatted(
                "home.pack.subtitle.due", locale: locale, arguments: regimenName(locale: locale), reminderTime
            )
        }
    }

    private func regimenName(locale: Locale) -> String {
        PackChoice(regimen).displayName(locale: locale)
    }

    private func nextPackWeekdayName(locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let weekday = (dayOneWeekday - 1 + regimen.totalDays) % 7
        return calendar.weekdaySymbols[weekday]
    }
}

//
//  DoseWindowExplainer.swift
//  Pillie
//

import Foundation

/// The 24-hour explainer behind Home's late line: one dose window, from the reminder that opened it to the next.
struct DoseWindowExplainer: Hashable, Sendable, Identifiable {
    enum Subject: Hashable, Sendable {
        case pill(number: Int)
        case patch
        case ring
    }

    let subject: Subject
    let opensAt: Date
    let closesAt: Date
    let reminderHour: Int
    let reminderMinute: Int
    let calendar: Calendar

    init?(subject: Subject, day: Date, reminderHour: Int, reminderMinute: Int, calendar: Calendar) {
        guard
            let opensAt = DoseWindow.reminder(for: day, hour: reminderHour, minute: reminderMinute, calendar: calendar),
            let closesAt = DoseWindow.deadline(for: day, hour: reminderHour, minute: reminderMinute, calendar: calendar)
        else { return nil }
        self.subject = subject
        self.opensAt = opensAt
        self.closesAt = closesAt
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.calendar = calendar
    }

    var id: Date { opensAt }

    /// Where midnight falls along the window, in real seconds so a DST night stays to scale.
    /// Nil when the reminder is at midnight itself.
    var midnightFraction: Double? {
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: opensAt)) else {
            return nil
        }
        let fraction = midnight.timeIntervalSince(opensAt) / closesAt.timeIntervalSince(opensAt)
        return fraction > 0 && fraction < 1 ? fraction : nil
    }

    func title(locale: Locale) -> String {
        let key = switch subject {
        case .pill: "home.window.title.pill"
        case .patch: "home.window.title.patch"
        case .ring: "home.window.title.ring"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    func body(locale: Locale) -> String {
        PillieLocalization.formatted("home.window.body", locale: locale, arguments: reminderTime(locale: locale))
    }

    func startLabel(now: Date, locale: Locale) -> String {
        let key = if !calendar.isDate(opensAt, inSameDayAs: now) {
            "home.window.start.yesterday"
        } else if reminderHour >= 18 {
            "home.window.start.tonight"
        } else {
            "home.window.start.today"
        }
        return PillieLocalization.formatted(key, locale: locale, arguments: reminderTime(locale: locale))
    }

    func endLabel(now: Date, locale: Locale) -> String {
        let key = calendar.isDate(closesAt, inSameDayAs: now) ? "home.window.end.today" : "home.window.end.tomorrow"
        return PillieLocalization.formatted(key, locale: locale, arguments: reminderTime(locale: locale))
    }

    func timeLeft(now: Date, locale: Locale) -> String {
        let minutes = Int(max(0, closesAt.timeIntervalSince(now)) / 60)
        let remaining = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .narrow)
            .locale(locale)
            .format(.seconds(minutes * 60))
        return PillieLocalization.formatted("home.window.end.left", locale: locale, arguments: remaining)
    }

    func midnightCaption(locale: Locale) -> String {
        switch subject {
        case .pill(let number):
            PillieLocalization.formatted("home.window.midnight.pill", locale: locale, arguments: number)
        case .patch, .ring:
            PillieLocalization.string("home.window.midnight.change", locale: locale)
        }
    }

    /// The ribbon read left to right as one VoiceOver label.
    func accessibilitySummary(now: Date, locale: Locale) -> String {
        var parts = [startLabel(now: now, locale: locale)]
        if midnightFraction != nil {
            parts += [
                PillieLocalization.string("home.window.midnight", locale: locale),
                midnightCaption(locale: locale),
            ]
        }
        parts += [
            endLabel(now: now, locale: locale),
            timeLeft(now: now, locale: locale),
            PillieLocalization.string("home.window.then_missed", locale: locale),
        ]
        return parts.joined(separator: ", ")
    }

    private func reminderTime(locale: Locale) -> String {
        SettingsPresentation.time(hour: reminderHour, minute: reminderMinute, locale: locale)
    }
}

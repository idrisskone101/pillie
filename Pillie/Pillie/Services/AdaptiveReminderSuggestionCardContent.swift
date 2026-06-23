//
//  AdaptiveReminderSuggestionCardContent.swift
//  Pillie
//
//  Pure value-type copy + gating for the Adaptive Reminder Time Suggestion card
//  shown on Home (#126). The card invites the user to shift their primary reminder
//  toward when they actually log. Pillie never silently changes the reminder time —
//  reminder time is a Schedule-Critical Setting that also anchors the blocking window
//  — so this surface only ever proposes; the change is applied through the normal
//  `PillStore` reminder-time path once the user accepts.
//
//  This is a Pillie Plus surface: `make` returns `nil` for free users (AC4) and when
//  the analyzer has no confident suggestion.
//

import Foundation

struct AdaptiveReminderSuggestionCardContent: Equatable {
    /// e.g. "You usually log around 8:40 AM".
    let headline: String
    /// Supporting line explaining the proposed shift.
    let body: String
    /// Accept CTA naming the target time, e.g. "Move reminder to 8:40 AM".
    let acceptTitle: String
    /// The proposed reminder time, applied through the normal `PillStore` path on accept.
    let suggestedHour: Int
    let suggestedMinute: Int
    /// Signed delta the suggestion is based on; recorded on dismissal so the same delta
    /// is not re-pitched during the cooldown.
    let deltaMinutes: Int

    static func make(
        suggestion: AdaptiveReminderTimeAnalyzer.Suggestion?,
        isPlus: Bool,
        locale: Locale = .current
    ) -> AdaptiveReminderSuggestionCardContent? {
        // Pillie Plus surface only — never appears for free users (AC4).
        guard isPlus, let suggestion else { return nil }

        let timeString = formattedTime(
            hour: suggestion.hour,
            minute: suggestion.minute,
            locale: locale
        )

        return AdaptiveReminderSuggestionCardContent(
            headline: "You usually log around \(timeString)",
            body: "Want to move your daily reminder to \(timeString) so it lands when you're ready?",
            acceptTitle: "Move reminder to \(timeString)",
            suggestedHour: suggestion.hour,
            suggestedMinute: suggestion.minute,
            deltaMinutes: suggestion.deltaMinutes
        )
    }

    /// Locale-aware 12/24-hour time string for an hour/minute-of-day.
    static func formattedTime(hour: Int, minute: Int, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        guard let date = calendar.date(from: components) else { return "" }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }
}

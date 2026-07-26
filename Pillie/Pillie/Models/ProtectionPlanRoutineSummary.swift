//
//  ProtectionPlanRoutineSummary.swift
//  Pillie
//
//  Model for the live "Your plan so far" card shown across Routine Method, Routine
//  Details, and Reminder Time (#77). It is the plan-builder thread the PRD asks for:
//  as the user commits each answer, the card fills in and its headline turns from an
//  invitation into a method-aware promise, so three setup screens feel like one plan
//  being assembled rather than a run of disconnected forms.
//
//  A pure value type — every input is already committed display text, so the derived
//  copy is deterministic and unit-testable without any view.
//

import Foundation

struct ProtectionPlanRoutineSummary: Equatable {
    var method: ContraceptiveMethod?
    /// Friendly schedule line, e.g. "Standard · 21 active, 7 break". Nil before details.
    var scheduleSummary: String?
    /// Current cycle day within the regimen. Nil before details.
    var cycleDay: Int?
    /// Formatted reminder time, e.g. "9:30 AM". Nil before the reminder-time screen.
    var reminderTimeText: String?
    var locale: Locale = .current

    /// Fixed card title.
    static var title: String {
        PillieLocalization.string("onboarding.plan.title")
    }

    struct Row: Equatable, Identifiable {
        let symbol: String
        let label: String
        let value: String

        var id: String { label }
    }

    /// Progressive, method-aware headline. An invitation before a method is chosen, a
    /// forward-looking promise once it is, and a concrete one once a time is set.
    var headline: String {
        method == nil
            ? PillieLocalization.string("onboarding.plan.subtitle", locale: locale)
            : PillieLocalization.string("onboarding.plan.title", locale: locale)
    }

    /// Receipt rows, appearing in the order the user commits them.
    var rows: [Row] {
        var rows: [Row] = []
        if let method {
            rows.append(
                Row(
                    symbol: "cross.case.fill",
                    label: PillieLocalization.string("onboarding.plan.method", locale: locale),
                    value: method.localizedTitle(locale: locale)
                )
            )
        }
        if let scheduleSummary {
            rows.append(
                Row(
                    symbol: "calendar",
                    label: PillieLocalization.string("onboarding.plan.schedule", locale: locale),
                    value: scheduleSummary
                )
            )
        }
        if let cycleDay {
            rows.append(
                Row(
                    symbol: "number",
                    label: PillieLocalization.string("onboarding.plan.current_cycle", locale: locale),
                    value: PillieLocalization.formatted(
                        "onboarding.cycle_position.day",
                        locale: locale,
                        arguments: cycleDay
                    )
                )
            )
        }
        if let reminderTimeText {
            rows.append(
                Row(
                    symbol: "bell.fill",
                    label: PillieLocalization.string("onboarding.demo.step.reminder", locale: locale),
                    value: reminderTimeText
                )
            )
        }
        return rows
    }

    /// Formats a 12-hour picker selection as display text, e.g. "9:30 AM". Shared by
    /// the Reminder Time preview and the plan card so the live time reads identically.
    static func clockText(
        hour12: Int,
        minute: Int,
        isPM: Bool,
        locale: Locale = .current
    ) -> String {
        let normalizedHour = (((hour12 - 1) % 12) + 12) % 12 + 1
        let normalizedMinute = max(0, min(59, minute))
        let hour24 = (normalizedHour % 12) + (isPM ? 12 : 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let date = calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2001,
                month: 1,
                day: 1,
                hour: hour24,
                minute: normalizedMinute
            )
        ) ?? Date(timeIntervalSince1970: 0)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

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

    /// Fixed card title.
    static let title = "Your plan so far"

    struct Row: Equatable, Identifiable {
        let symbol: String
        let label: String
        let value: String

        var id: String { label }
    }

    /// Progressive, method-aware headline. An invitation before a method is chosen, a
    /// forward-looking promise once it is, and a concrete one once a time is set.
    var headline: String {
        guard let method else {
            return "Let's build your protection plan."
        }
        let language = MethodActionLanguage(method: method)
        if let reminderTimeText {
            return "Pillie protects \(language.objectNoun) at \(reminderTimeText)."
        }
        return "Pillie will protect \(language.objectNoun)."
    }

    /// Receipt rows, appearing in the order the user commits them.
    var rows: [Row] {
        var rows: [Row] = []
        if let method {
            rows.append(Row(symbol: "cross.case.fill", label: "Method", value: method.title))
        }
        if let scheduleSummary {
            rows.append(Row(symbol: "calendar", label: "Schedule", value: scheduleSummary))
        }
        if let cycleDay {
            rows.append(Row(symbol: "number", label: "Cycle day", value: "Day \(cycleDay)"))
        }
        if let reminderTimeText {
            rows.append(Row(symbol: "bell.fill", label: "Reminder", value: reminderTimeText))
        }
        return rows
    }

    /// Formats a 12-hour picker selection as display text, e.g. "9:30 AM". Shared by
    /// the Reminder Time preview and the plan card so the live time reads identically.
    static func clockText(hour12: Int, minute: Int, isPM: Bool) -> String {
        let normalizedHour = (((hour12 - 1) % 12) + 12) % 12 + 1
        let normalizedMinute = max(0, min(59, minute))
        return String(format: "%d:%02d %@", normalizedHour, normalizedMinute, isPM ? "PM" : "AM")
    }
}

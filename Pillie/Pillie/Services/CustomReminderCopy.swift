//
//  CustomReminderCopy.swift
//  Pillie
//

import Foundation

struct CustomReminderMessages: Equatable {
    var dueTitle: String
    var dueBody: String
    var retryTitle: String
    var retryBody: String
    var lastCallTitle: String
    var lastCallBody: String
}

struct CustomReminderDraft: Equatable {
    var messages: CustomReminderMessages
    private(set) var appliedPreset: CustomReminderPreset?
    private let originalMessages: CustomReminderMessages

    init(messages: CustomReminderMessages) {
        self.messages = messages
        self.appliedPreset = nil
        self.originalMessages = messages
    }

    var wasEditedAfterPreset: Bool {
        guard let appliedPreset else { return false }
        return messages != appliedPreset.messages
    }

    mutating func apply(_ preset: CustomReminderPreset) {
        messages = preset.messages
        appliedPreset = preset
    }

    mutating func restoreDefaults(_ defaults: CustomReminderMessages) {
        messages = defaults
        appliedPreset = nil
    }

    mutating func discardChanges() {
        messages = originalMessages
        appliedPreset = nil
    }
}

enum CustomReminderPreset: String, CaseIterable, Identifiable {
    case gentle
    case direct
    case encouraging
    case privateDiscreet = "private_discreet"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle: "Gentle"
        case .direct: "Direct"
        case .encouraging: "Encouraging"
        case .privateDiscreet: "Private / discreet"
        }
    }

    static func matching(_ messages: CustomReminderMessages) -> Self? {
        allCases.first { $0.messages == messages }
    }

    var messages: CustomReminderMessages {
        switch self {
        case .gentle:
            CustomReminderMessages(
                dueTitle: "A gentle reminder",
                dueBody: "It’s time to check in with Pillie.",
                retryTitle: "Still time to check in",
                retryBody: "Open Pillie when you’re ready.",
                lastCallTitle: "One last reminder",
                lastCallBody: "Open Pillie to update today’s status."
            )
        case .direct:
            CustomReminderMessages(
                dueTitle: "Pillie check-in due",
                dueBody: "Open Pillie to mark today’s pill.",
                retryTitle: "Pillie check-in waiting",
                retryBody: "Open Pillie to update your status.",
                lastCallTitle: "Final Pillie reminder",
                lastCallBody: "Open Pillie to complete or update today’s check-in."
            )
        case .encouraging:
            CustomReminderMessages(
                dueTitle: "You’re building consistency",
                dueBody: "Open Pillie for today’s check-in.",
                retryTitle: "Keep your routine moving",
                retryBody: "Open Pillie to update today’s status.",
                lastCallTitle: "Finish today’s check-in",
                lastCallBody: "Open Pillie for one final check-in."
            )
        case .privateDiscreet:
            CustomReminderMessages(
                dueTitle: "Time for your check-in",
                dueBody: "Open Pillie when convenient.",
                retryTitle: "Check-in still pending",
                retryBody: "Open Pillie when convenient.",
                lastCallTitle: "Final check-in reminder",
                lastCallBody: "Open Pillie to update your status."
            )
        }
    }
}

/// Pure value-type resolver for the Custom Reminder Message perk (Pillie+).
///
/// Given a raw stored custom string, the existing default copy, the hard cap, and
/// the Plus entitlement, it returns the *effective* string that will actually fire
/// for a Due Action Reminder field. All length/fallback logic lives here, never
/// inside `NotificationManager` (ADR 0004):
///
/// - Not Plus → the default copy (free users get exactly the existing method-aware copy).
/// - Plus + blank/whitespace-only custom → the default copy (an empty field can never fire).
/// - Plus + non-blank custom → the custom string with surrounding whitespace trimmed and
///   clamped to `cap` by `Character` count, so emoji and punctuation are preserved exactly.
enum CustomReminderCopy {
    /// Hard cap on the Due Action Reminder title, enforced by the editor and clamped here.
    static let titleCap = 50
    /// Hard cap on the Due Action Reminder body, enforced by the editor and clamped here.
    static let bodyCap = 150

    /// Resolves the effective copy for one Due Action Reminder field.
    static func effective(
        custom: String,
        default defaultCopy: String,
        cap: Int,
        isPlus: Bool
    ) -> String {
        guard isPlus else { return defaultCopy }
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultCopy }
        return String(trimmed.prefix(cap))
    }

    /// Whether a stored raw field counts as customized — i.e. it has a non-blank value
    /// once surrounding whitespace is removed. Used for coarse, content-free telemetry.
    static func isCustomized(_ raw: String) -> Bool {
        !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

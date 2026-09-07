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
}

struct CustomReminderDraft: Equatable {
    var messages: CustomReminderMessages
    private(set) var appliedPreset: CustomReminderPreset?
    private var appliedPresetMessages: CustomReminderMessages?
    private let originalMessages: CustomReminderMessages

    init(messages: CustomReminderMessages) {
        self.messages = messages
        self.appliedPreset = nil
        self.appliedPresetMessages = nil
        self.originalMessages = messages
    }

    var wasEditedAfterPreset: Bool {
        guard appliedPreset != nil, let appliedPresetMessages else { return false }
        return messages != appliedPresetMessages
    }

    mutating func apply(_ preset: CustomReminderPreset, locale: Locale = .current) {
        let localizedMessages = preset.localizedMessages(locale: locale)
        messages = localizedMessages
        appliedPreset = preset
        appliedPresetMessages = localizedMessages
    }

    mutating func restoreDefaults(_ defaults: CustomReminderMessages) {
        messages = defaults
        appliedPreset = nil
        appliedPresetMessages = nil
    }

    mutating func discardChanges() {
        messages = originalMessages
        appliedPreset = nil
        appliedPresetMessages = nil
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

    func localizedDisplayName(locale: Locale = .current) -> String {
        let key = switch self {
        case .gentle: "settings.tone.gentle"
        case .direct: "settings.tone.direct"
        case .encouraging: "settings.tone.encouraging"
        case .privateDiscreet: "settings.tone.private"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    static func matching(
        _ messages: CustomReminderMessages,
        locale: Locale = .current
    ) -> Self? {
        allCases.first {
            $0.messages == messages || $0.localizedMessages(locale: locale) == messages
        }
    }

    func localizedMessages(locale: Locale = .current) -> CustomReminderMessages {
        let localizedPresetLanguages = ["de", "it"]
        guard let languageCode = locale.language.languageCode?.identifier,
              localizedPresetLanguages.contains(languageCode) else {
            return messages
        }
        let stem = switch self {
        case .gentle: "notification.custom.gentle"
        case .direct: "notification.custom.direct"
        case .encouraging: "notification.custom.encouraging"
        case .privateDiscreet: "notification.custom.private"
        }
        return CustomReminderMessages(
            dueTitle: PillieLocalization.string(
                "\(stem).title",
                locale: locale
            ),
            dueBody: PillieLocalization.string("\(stem).primary", locale: locale),
            retryTitle: PillieLocalization.string("notification.followup.title", locale: locale),
            retryBody: PillieLocalization.string("\(stem).followup", locale: locale)
        )
    }

    var messages: CustomReminderMessages {
        switch self {
        case .gentle:
            CustomReminderMessages(
                dueTitle: "A gentle reminder",
                dueBody: "It’s time to check in with Pillie.",
                retryTitle: "Still time to check in",
                retryBody: "Open Pillie when you’re ready.",
            )
        case .direct:
            CustomReminderMessages(
                dueTitle: "Pillie check-in due",
                dueBody: "Open Pillie to mark today’s pill.",
                retryTitle: "Pillie check-in waiting",
                retryBody: "Open Pillie to update your status.",
            )
        case .encouraging:
            CustomReminderMessages(
                dueTitle: "You’re building consistency",
                dueBody: "Open Pillie for today’s check-in.",
                retryTitle: "Keep your routine moving",
                retryBody: "Open Pillie to update today’s status.",
            )
        case .privateDiscreet:
            CustomReminderMessages(
                dueTitle: "Time for your check-in",
                dueBody: "Open Pillie when convenient.",
                retryTitle: "Check-in still pending",
                retryBody: "Open Pillie when convenient.",
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

//
//  CustomReminderCopy.swift
//  Pillie
//

import Foundation

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

//  The post-trial win-back pushes (ENG-173): at most three local
//  notifications after a hard-paywall Reverse Trial ends unpaid, then none.

import Foundation

/// One row per win-back push. The raw value is the analytics `slot` and part
/// of the request id. Days count forward from the expiry day, never from the
/// grant, so a break week that slides expiry moves the pushes with it (same
/// rule as `ReminderSchedulePlanner.trialNoticeSlots`). Trial days 15, 16,
/// and 22. Raw value 3 stays retired so slot 4 keeps its analytics `slot`.
enum WinbackSlot: Int, CaseIterable, Codable {
    case expiryDay = 1
    case dayAfter = 2
    case lastNote = 4

    enum FireTime {
        /// Two hours before the reminder time, never before 09:00.
        case lead
        /// The reminder time itself: the moment the reminder no longer fires.
        case reminder
    }

    var calendarDaysAfterExpiry: Int {
        switch self {
        case .expiryDay: 0
        case .dayAfter: 1
        case .lastNote: 7
        }
    }

    var fireTime: FireTime {
        switch self {
        case .dayAfter: .reminder
        case .expiryDay, .lastNote: .lead
        }
    }
}

/// Picks the copy, and is the analytics `variant` value.
enum WinbackVariant: String, Codable {
    case reminder
    case blocker
    /// Slot 2's A/B challenger arm, reminder-only users only.
    case notAReminder = "not_a_reminder"
    /// Slot 4 for someone who logged three days or more.
    case days
    /// Slot 4 for someone who logged two days or fewer.
    case new
}

/// What the words name, one case per slot.
enum WinbackDetail: Hashable {
    /// Slots 1 and 2: the reminder time that no longer fires.
    case reminderTime(hour: Int, minute: Int)
    /// Slot 4: the days she logged, for the thank-you.
    case daysLogged(Int)
}

struct WinbackIntent: Hashable {
    let slot: WinbackSlot
    let variant: WinbackVariant
    let fireDate: Date
    let detail: WinbackDetail
}

/// What the win-back plan needs beyond `ReminderSchedulePlanner.Input`.
/// NotificationManager builds it only for a hard-paywall user with a grant and
/// no entitlement, so nobody else pays for the dose-history walk.
struct WinbackContext {
    let daysLogged: Int
    let lastAppOpen: Date?
    let slot2Arm: WinbackSlot2Arm
}

/// Slot 2's A/B arm, assigned once per install (`WinbackSlot2Arm.assigned`).
enum WinbackSlot2Arm: String {
    case control
    case challenger
}

/// A tapped win-back push: what the wall reports, and what a conversion in
/// the next day is attributed to.
struct WinbackOpen: Codable, Equatable {
    static let attributionWindow: TimeInterval = 24 * 60 * 60

    let slot: WinbackSlot
    let variant: WinbackVariant
    let date: Date

    func attributes(at now: Date) -> Bool {
        let age = now.timeIntervalSince(date)
        return age >= 0 && age < Self.attributionWindow
    }
}

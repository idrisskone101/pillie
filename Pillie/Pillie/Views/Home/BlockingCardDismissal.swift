//
//  BlockingCardDismissal.swift
//  Pillie
//
//  The X on Today's "set up app blocking" card.
//

import Foundation

/// One X hides the card until a check-in next goes late or is missed, when
/// the card comes back once. A second X hides it for good. Most people who
/// skip blocking in onboarding never set it up later, and a slip is when the
/// ask is worth repeating.
struct BlockingCardDismissal: Equatable {
    static let dismissedKey = "homeBlockingStatusCardDismissed"
    static let dismissedAtKey = "homeBlockingStatusCardDismissedAt"
    static let returnedKey = "homeBlockingStatusCardReturned"

    /// How many days back Today looks for a missed check-in.
    static let lookbackDays = 7

    var isDismissed = false
    /// When X was tapped. Nil with `isDismissed` is a dismissal from before
    /// an X could expire.
    var dismissedAt: Date?
    /// The card has come back once, so the next X is final.
    var hasReturned = false

    mutating func dismiss(at now: Date) {
        isDismissed = true
        dismissedAt = now
    }

    /// `slips` are the reminder times of check-ins that are late now or were
    /// missed. Only a reminder that fired after the X counts, so the slip the
    /// user dismissed the card during never brings it straight back. An
    /// undated dismissal counts from `now`.
    mutating func refresh(now: Date, slips: [Date]) {
        guard isDismissed else { return }
        guard let dismissedAt else {
            self.dismissedAt = now
            return
        }
        guard !hasReturned, slips.contains(where: { $0 > dismissedAt }) else { return }
        isDismissed = false
        hasReturned = true
    }
}

extension PillStore {
    /// Reminder times of recent check-ins that are late now or were missed,
    /// as `BlockingCardDismissal.refresh` reads them.
    func recentCheckInSlips(calendar: Calendar = .current) -> [Date] {
        (0..<BlockingCardDismissal.lookbackDays).compactMap { daysAgo in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            switch doseStanding(on: day) {
            case .late, .missed:
                return reminderClock.reminder(on: day)
            case .upcoming, .taken, nil:
                return nil
            }
        }
    }
}

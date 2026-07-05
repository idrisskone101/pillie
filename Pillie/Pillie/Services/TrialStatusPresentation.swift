//
//  TrialStatusPresentation.swift
//  Pillie
//
//  Drives the in-trial "Plus trial — N days left" indicator and its status
//  sheet (issue #166 / ADR 0007). Pure presentation logic (no SwiftUI) so the
//  visibility and day-count contract is testable as a value type: visible only
//  during an active Reverse Trial without an entitlement, with day copy that
//  agrees with the midnight-after-day-14 expiry rule ("ends tonight" on the
//  last protected day, never a misleading "0 days left").
//

import Foundation

struct TrialStatusPresentation: Equatable {
    /// Local-day rollovers until expiry (`ReverseTrialClock.daysRemaining`).
    let daysRemaining: Int

    /// Day count as shown to the user: the trial promises "14 days free", so
    /// the partial grant day (15 rollovers left) never reads above the promise.
    var displayedDaysRemaining: Int {
        min(daysRemaining, ReverseTrialClock.fullDays)
    }

    /// Whether the trial expires at tonight's local-day rollover — the whole
    /// last day is still protected, so copy says "ends tonight", never "0 days
    /// left" (misleading while active) or "1 days left".
    var endsTonight: Bool {
        daysRemaining == 1
    }

    /// The persistent indicator's copy, e.g. "Plus trial — 5 days left".
    var indicatorLabel: String {
        endsTonight
            ? "Plus trial — ends tonight"
            : "Plus trial — \(displayedDaysRemaining) days left"
    }

    /// Copy for the trial status sheet behind the indicator.
    var sheetContent: TrialStatusSheetContent {
        TrialStatusSheetContent(
            title: endsTonight
                ? "Your Plus trial ends tonight"
                : "\(displayedDaysRemaining) days left in your Plus trial",
            // Matches the Trial Granted Moment's perk list.
            unlockedItems: [
                "App blocking", "Shake to confirm", "Smart Reminders", "Custom messages",
            ],
            expiryItems: [
                "App blocking turns off",
                "Reminders stay free, forever",
                "Your blocker setup is saved",
            ],
            ctaTitle: "Keep Pillie Plus"
        )
    }

    /// The indicator + sheet surface, or `nil` when no indicator should exist:
    /// entitled users (including mid-trial purchases), expired trials, or no
    /// trial ever granted.
    static func make(
        state: PlusAccessState,
        calendar: Calendar,
        now: Date
    ) -> TrialStatusPresentation? {
        // Entitlement wins over a still-running trial clock: a mid-trial
        // purchase removes the indicator immediately.
        guard !state.hasEntitlement, let grantDate = state.trialGrantDate else { return nil }
        let clock = ReverseTrialClock(grantDate: grantDate)
        guard clock.isActive(calendar: calendar, now: now) else { return nil }
        return TrialStatusPresentation(
            daysRemaining: clock.daysRemaining(calendar: calendar, now: now)
        )
    }
}

/// Copy for the trial status sheet: remaining time, what's unlocked, what
/// expiry changes, and the quiet "Keep Plus" path into the existing purchase
/// flow — the only in-trial purchase surface besides the Settings row.
struct TrialStatusSheetContent: Equatable {
    let title: String
    let unlockedItems: [String]
    let expiryItems: [String]
    let ctaTitle: String
}

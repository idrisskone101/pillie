//
//  SmartRemindersMigrationNotice.swift
//  Pillie
//

import Foundation

/// One-time migration notice shown when Smart Reminders moves to Pillie+ (ADR 0004).
///
/// Free users today already receive auto-retries and Snooze, so the gate (#101) silently
/// reduces their reminder behavior. On the first launch after the update, affected free
/// users see a reassurance-first notice ("Your daily reminder is still active") that then
/// introduces Smart Reminders as a Plus perk with an upgrade path.
///
/// Detection uses a one-time marker recorded at launch: if the marker is absent and
/// onboarding is already complete, a non-Plus user is eligible. Plus users and brand-new /
/// mid-onboarding users (for whom Smart Reminders was always Plus) are never eligible, and
/// the notice is shown at most once.
enum SmartRemindersMigrationNotice {
    /// Set once, on the first launch after the Smart Reminders gate shipped. Its presence
    /// means eligibility has already been resolved, so the notice is never re-evaluated.
    static let markerKey = "smartRemindersMigrationNoticeEvaluated"

    /// Copy for the notice, kept as a value type so the reassurance-first framing can be
    /// unit-tested without rendering the view.
    struct Content: Equatable {
        let reassuranceTitle: String
        let reassuranceBody: String
        /// Reuses the Smart Reminders upsell component from #102 for the upgrade framing.
        let upsell: PlusUpsellContent
    }

    static let content = Content(
        reassuranceTitle: "Your daily reminder is still active",
        reassuranceBody: "Nothing changes about your daily reminder — it still arrives at your set time, every day. The gentle follow-up nudges after that first reminder are now part of Pillie+.",
        upsell: .smartReminders
    )

    /// Pure eligibility decision. Eligible only for a pre-existing free user: the one-time
    /// evaluation has not run, onboarding is already complete, and the user is not Plus.
    static func isEligible(alreadyEvaluated: Bool, onboardingComplete: Bool, isPlus: Bool) -> Bool {
        guard !alreadyEvaluated, onboardingComplete, !isPlus else { return false }
        return true
    }

    /// Runs the one-time evaluation against persisted state. Always sets the marker so the
    /// decision is made exactly once — even for an ineligible (Plus or mid-onboarding) user,
    /// so a later free state can never resurface the notice. Returns whether to present it.
    @discardableResult
    static func evaluate(defaults: UserDefaults, onboardingComplete: Bool, isPlus: Bool) -> Bool {
        let alreadyEvaluated = defaults.bool(forKey: markerKey)
        let eligible = isEligible(
            alreadyEvaluated: alreadyEvaluated,
            onboardingComplete: onboardingComplete,
            isPlus: isPlus
        )
        defaults.set(true, forKey: markerKey)
        return eligible
    }
}

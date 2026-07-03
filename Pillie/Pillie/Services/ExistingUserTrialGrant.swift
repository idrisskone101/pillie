//
//  ExistingUserTrialGrant.swift
//  Pillie
//
//  Issue #165 (Reverse Trial 6/10 / ADR 0007): grant the Reverse Trial to the
//  existing base on first launch after the introducing update. Mirrors
//  `ReviewPromptEligibility`: a pure value-type classifier that decides whether
//  this launch grants the trial and shows the one-time announcement sheet.
//

import Foundation

enum ExistingUserTrialGrant {
    /// Whether this launch grants the trial and shows the announcement sheet.
    enum Decision: Equatable {
        /// Grant the Reverse Trial, fire `trial_granted` (source: update), and
        /// present the one-time announcement sheet.
        case grantAndAnnounce
        /// No grant this launch, with the reason. The reason is never reported as
        /// telemetry; it exists so each exclusion branch is asserted independently.
        case suppressed(Reason)

        /// Why this launch does not grant.
        enum Reason: Equatable {
            /// Onboarding has not completed — the Trial Granted Moment owns the
            /// grant for this user; they must never be granted twice.
            case stillOnboarding
            /// A paying Plus subscriber — sees nothing and changes in no way.
            case alreadyEntitled
            /// A Reverse Trial grant already exists (active or expired) — the
            /// 14-day clock is never restarted.
            case alreadyTrialed
            /// The one-shot update window was consumed on a previous launch —
            /// the announcement shows exactly once.
            case alreadyHandled
            /// RevenueCat entitlement state has not loaded yet this launch — too
            /// early to tell a subscriber from a free user, so no decision is
            /// made and the window stays open.
            case entitlementUnresolved
        }
    }

    /// The launch state the decision is derived from.
    struct State: Equatable {
        /// Whether onboarding has ever completed. Mid-onboarding users get the
        /// onboarding grant at the Trial Granted Moment instead — never both.
        let isOnboardingComplete: Bool
        /// Whether the RevenueCat entitlement state has actually loaded this
        /// launch. `hasEntitlement` starts `false` before the first customer-info
        /// fetch, so deciding earlier would misread a paying subscriber as free.
        let isEntitlementResolved: Bool
        /// The raw Plus entitlement — paying subscribers see nothing.
        let hasEntitlement: Bool
        /// Whether a Reverse Trial grant already exists (Keychain), e.g. from the
        /// onboarding Trial Granted Moment.
        let hasTrialGrant: Bool
        /// Whether the one-shot update window was already consumed on a previous
        /// launch.
        let alreadyHandled: Bool
    }

    /// UserDefaults key for the persisted one-shot window flag. Stable: renaming
    /// it would re-show the announcement to users who already saw it.
    static let handledStorageKey = "updateTrialGrantHandled"

    static func evaluate(for state: State) -> Decision {
        if !state.isOnboardingComplete {
            return .suppressed(.stillOnboarding)
        }
        if state.alreadyHandled {
            return .suppressed(.alreadyHandled)
        }
        if !state.isEntitlementResolved {
            return .suppressed(.entitlementUnresolved)
        }
        if state.hasEntitlement {
            return .suppressed(.alreadyEntitled)
        }
        if state.hasTrialGrant {
            return .suppressed(.alreadyTrialed)
        }
        return .grantAndAnnounce
    }

    /// Whether this decision consumes the one-shot update window (the caller
    /// persists the handled flag). Terminal outcomes — a grant, an entitled
    /// subscriber, an already-trialed user — close it: they must not receive a
    /// surprise grant on some later launch (e.g. after churning), which would no
    /// longer be "first launch after the introducing update". Undecided launches
    /// (mid-onboarding, entitlement not yet loaded) leave it open so the check
    /// runs again; `alreadyHandled` means the flag is already persisted.
    static func closesWindow(_ decision: Decision) -> Bool {
        switch decision {
        case .grantAndAnnounce,
             .suppressed(.alreadyEntitled),
             .suppressed(.alreadyTrialed):
            return true
        case .suppressed(.stillOnboarding),
             .suppressed(.entitlementUnresolved),
             .suppressed(.alreadyHandled):
            return false
        }
    }
}

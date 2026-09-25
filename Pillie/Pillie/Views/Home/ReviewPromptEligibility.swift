//
//  ReviewPromptEligibility.swift
//  Pillie
//
//  Pure gating seam for the Home Review Prompt's Sentiment Gate (PRD #132 /
//  ADR 0005). Mirrors `ProtectionPlanCompletion.outcome(for:)`: a value-type
//  classifier that decides whether the "Enjoying Pillie?" card may appear, and why
//  it is suppressed when it does not.
//
//  Eligibility is an unbroken Streak crossing a method-aware threshold — pill
//  `>= 3`, patch `>= 1`, ring `>= 2`. Because a Streak counts completed due
//  actions (not calendar days) and cadence differs by method, a single fixed
//  threshold would ask pill users in a week and effectively never ask ring
//  users. Ring is `>= 2` (not `>= 1`) so the day-one ring insertion does not
//  fire the prompt at setup. A Streak inherently encodes tenure, so there is no
//  separate days-since-install floor.
//
//  The full lifecycle lives here so every branch — thresholds, permanent
//  suppression, the soft-dismiss cooldown, the lifetime cap, and yielding to a
//  higher-priority Home card — is value-type tested without hosted XCTest.
//

import Foundation

enum ReviewPromptEligibility {
    /// Whether the Sentiment Gate card may render this visit, or the reason it is hidden.
    enum Decision: Equatable {
        /// Eligible — render the "Enjoying Pillie?" card.
        case show
        /// Hidden, with the reason it was suppressed. The reason is never reported as
        /// telemetry; it exists so each suppression branch is asserted independently.
        case suppressed(Reason)

        /// Why the Sentiment Gate card is hidden this visit.
        enum Reason: Equatable {
            /// Streak has not yet crossed the method-aware threshold. Also the
            /// streak-broke-before-responding case — the card quietly disappears.
            case ineligibleStreak
            /// The user already answered the Sentiment Gate (positive or negative).
            case permanentlySuppressed
            /// Within the cooldown window after a soft dismiss.
            case inCooldown
            /// Soft-dismissed the maximum number of times — permanently capped.
            case lifetimeCapReached
            /// A higher-priority Home card (Refill / Blocking) is showing this pass;
            /// the rating ask yields (one ask per visit).
            case yieldingToOtherCard
        }
    }

    /// The success/suppression state captured when Home renders.
    struct State: Equatable {
        /// The active contraception method, which sets the Streak threshold.
        let method: ContraceptiveMethod
        /// The current unbroken Streak (completed due actions).
        let currentStreak: Int
        /// Whether the prompt was permanently answered (positive/negative) before.
        let permanentlySuppressed: Bool
        /// When the card was last soft-dismissed (the close control), or `nil`.
        let lastSoftDismissal: Date?
        /// How many times the card has been soft-dismissed.
        let softDismissalCount: Int
        /// Whether a higher-priority Home card would render this pass.
        let higherPriorityCardShowing: Bool
        /// The current moment, driving the cooldown check.
        let now: Date
    }

    /// Days the card stays hidden after a soft dismiss before it may re-show. A rating
    /// ask is higher-stakes and shares Apple's annual prompt budget (ADR 0005).
    static let softDismissalCooldownDays = 90
    /// Total appearances before the card is permanently suppressed. Each soft dismiss is
    /// one appearance; the card appears at most this many times.
    static let softDismissalLifetimeCap = 3

    /// The method-aware Streak threshold at which the prompt becomes eligible.
    static func threshold(for method: ContraceptiveMethod) -> Int {
        switch method {
        case .pill: return 3
        case .patch: return 1
        case .ring: return 2
        }
    }

    /// The single source of truth for whether the card shows. Precedence: answered
    /// (permanent) → lifetime cap → ineligible Streak → cooldown → yield → show. The
    /// foundational success gate (Streak) and the terminal suppression states outrank the
    /// transient card-competition yield, which is only reported when the card would
    /// otherwise be fully eligible.
    static func evaluate(for state: State) -> Decision {
        if state.permanentlySuppressed {
            return .suppressed(.permanentlySuppressed)
        }
        if state.softDismissalCount >= softDismissalLifetimeCap {
            return .suppressed(.lifetimeCapReached)
        }
        if state.currentStreak < threshold(for: state.method) {
            return .suppressed(.ineligibleStreak)
        }
        if let lastSoftDismissal = state.lastSoftDismissal,
           isWithinCooldown(lastSoftDismissal: lastSoftDismissal, now: state.now) {
            return .suppressed(.inCooldown)
        }
        if state.higherPriorityCardShowing {
            return .suppressed(.yieldingToOtherCard)
        }
        return .show
    }

    /// Whether `now` is still inside the cooldown window after a soft dismiss. The window
    /// closes exactly `softDismissalCooldownDays` after the dismissal (boundary shows).
    static func isWithinCooldown(lastSoftDismissal: Date, now: Date) -> Bool {
        let cooldown = TimeInterval(softDismissalCooldownDays) * 86_400
        return now.timeIntervalSince(lastSoftDismissal) < cooldown
    }
}

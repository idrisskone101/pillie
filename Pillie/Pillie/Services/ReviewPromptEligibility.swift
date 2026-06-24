//
//  ReviewPromptEligibility.swift
//  Pillie
//
//  Pure gating seam for the Home Review Prompt's Sentiment Gate (PRD #132 /
//  ADR 0005). Mirrors `ProtectionPlanCompletion.outcome(for:)`: a value-type
//  classifier that decides whether the "Enjoying Pillie?" card may appear.
//
//  Eligibility is an unbroken Streak crossing a method-aware threshold — pill
//  `>= 3`, patch `>= 1`, ring `>= 2`. Because a Streak counts completed due
//  actions (not calendar days) and cadence differs by method, a single fixed
//  threshold would ask pill users in a week and effectively never ask ring
//  users. Ring is `>= 2` (not `>= 1`) so the day-one ring insertion does not
//  fire the prompt at setup. A Streak inherently encodes tenure, so there is no
//  separate days-since-install floor.
//
//  This tracer slice (#133) covers eligibility + permanent suppression only; the
//  soft-dismiss cooldown, lifetime cap, and card competition land in later slices.
//

enum ReviewPromptEligibility {
    /// Whether the Sentiment Gate card may render this visit.
    enum Decision: Equatable {
        /// Eligible — render the "Enjoying Pillie?" card.
        case show
        /// Not eligible (below threshold) or permanently suppressed — render nothing.
        case hide
    }

    /// The success/suppression state captured when Home renders.
    struct State: Equatable {
        /// The active contraception method, which sets the Streak threshold.
        let method: ContraceptiveMethod
        /// The current unbroken Streak (completed due actions).
        let currentStreak: Int
        /// Whether the prompt was permanently answered (positive/negative) before.
        let permanentlySuppressed: Bool
    }

    /// The method-aware Streak threshold at which the prompt becomes eligible.
    static func threshold(for method: ContraceptiveMethod) -> Int {
        switch method {
        case .pill: return 3
        case .patch: return 1
        case .ring: return 2
        }
    }

    /// `.show` iff the prompt has never been answered and the Streak has crossed the
    /// method-aware threshold; otherwise `.hide`.
    static func evaluate(for state: State) -> Decision {
        guard !state.permanentlySuppressed else { return .hide }
        return state.currentStreak >= threshold(for: state.method) ? .show : .hide
    }
}

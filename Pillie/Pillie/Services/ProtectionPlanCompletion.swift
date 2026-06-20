//
//  ProtectionPlanCompletion.swift
//  Pillie
//
//  Classifies the terminal onboarding-completion state for Pillie's app-blocking
//  differentiator. See CONTEXT.md / ADR 0003: Protection Plan Activation requires
//  onboarding completion, a saved blocker configuration, AND completed Screen Time
//  authorization. Everything else is Reminder-Only Onboarding Completion, even when
//  the user holds a Plus entitlement.
//

enum ProtectionPlanCompletion {
    /// The completed-onboarding classification.
    enum Outcome: Equatable {
        /// Reminders are ready; app blocking remains incomplete. Holds regardless of
        /// Plus entitlement (free, Plus-but-skipped, or Plus-but-denied Screen Time).
        case reminderOnly
        /// Onboarding completed + saved blocker config + Screen Time authorization.
        case protectionPlanActivated

        /// The Product Analytics Telemetry event that reports this classification.
        /// Reminder-only completion reports `reminder_only_completion` and never the
        /// activation event; only genuine activation reports `protection_plan_activated`.
        var analyticsEvent: AnalyticsEvent {
            switch self {
            case .reminderOnly: return .reminderOnlyCompletion
            case .protectionPlanActivated: return .protectionPlanActivated
            }
        }
    }

    /// The blocker/entitlement state captured at the moment onboarding completes.
    struct State: Equatable {
        /// Plus / trial / restored / already-entitled. Kept even when reminder-only.
        let isEntitled: Bool
        /// Whether iOS Screen Time authorization completed successfully.
        let screenTimeAuthorized: Bool
        /// Whether a non-empty blocker configuration (apps/categories) was saved.
        let blockerConfigSaved: Bool
    }

    /// Activation requires both a saved blocker config and Screen Time authorization.
    /// Authorized-but-empty selection, skipped, or denied all stay reminder-only.
    static func outcome(for state: State) -> Outcome {
        if state.blockerConfigSaved && state.screenTimeAuthorized {
            return .protectionPlanActivated
        }
        return .reminderOnly
    }

    /// Whether the user holds a Plus entitlement but has not activated app blocking —
    /// the "Plus but reminder-only" case. The UI must not describe them as free, while
    /// still offering a path to enable blocking later.
    static func hasUnactivatedEntitlement(for state: State) -> Bool {
        state.isEntitled && outcome(for: state) == .reminderOnly
    }
}

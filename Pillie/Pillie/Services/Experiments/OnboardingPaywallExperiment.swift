//
//  OnboardingPaywallExperiment.swift
//  Pillie
//

import Foundation

/// The onboarding paywall A/B test (ENG-205). Each eligible fresh install gets one
/// arm from the PostHog flag, persisted in the Keychain and never re-rolled.
nonisolated enum OnboardingPaywallExperiment {
    static let experimentName = "onboarding_paywall_v1"
    static let flagKey = "onboarding-paywall-arm"
    /// RevenueCat offering the `hard_trial` arm sells: Annual is
    /// `plus.annual.extend` (7 days free), plus Monthly and Lifetime.
    static let offeringID = "onboarding_trial"

    /// A stored enrollment always wins so an arm is never re-rolled. A Keychain trial
    /// grant without a stored enrollment means a reinstall, which would bias the arms.
    static func enrollment(
        stored: OnboardingPaywallEnrollment?,
        hasExistingAppState: Bool,
        hasTrialGrant: Bool,
        now: Date,
        appVersion: String
    ) -> OnboardingPaywallEnrollment {
        if let stored { return stored }
        if hasExistingAppState || hasTrialGrant {
            return .assigned(OnboardingPaywallAssignment(
                arm: .control,
                source: .excluded,
                assignedAt: now,
                appVersion: appVersion
            ))
        }
        return .pending(since: now)
    }

    /// `nil` means flags have not loaded or the flag is missing, so the install
    /// stays pending and the next launch retries.
    static func assignment(
        forFlagValue value: Any?,
        now: Date,
        appVersion: String
    ) -> OnboardingPaywallAssignment? {
        guard let value else { return nil }
        let arm = (value as? String).flatMap(OnboardingPaywallArm.init(rawValue:))
        return OnboardingPaywallAssignment(
            arm: arm ?? .control,
            source: arm == nil ? .flagOff : .flag,
            assignedAt: now,
            appVersion: appVersion
        )
    }

    /// The App Review link may pick the arm only before the flows diverge, so it never
    /// moves anyone who already saw an arm. It ignores the reinstall exclusion: review
    /// devices keep Keychain trial grants from earlier builds.
    static func acceptsReviewOverride(onboardingStep: Int?) -> Bool {
        guard let onboardingStep else { return true }
        guard let step = OnboardingFlow.visibleStep(
            for: onboardingStep,
            isPlus: false,
            selectedFreePlan: false
        ),
        let index = OnboardingFlow.displayIndex(for: step.rawValue),
        let diagnosis = OnboardingFlow.displayIndex(for: OnboardingFlow.Step.reminderPlan.rawValue)
        else { return false }
        return index <= diagnosis
    }

    static func lockedAssignment(
        _ enrollment: OnboardingPaywallEnrollment,
        now: Date,
        appVersion: String
    ) -> OnboardingPaywallAssignment {
        switch enrollment {
        case .assigned(let assignment):
            return assignment
        case .pending:
            return OnboardingPaywallAssignment(
                arm: .control,
                source: .offlineDefault,
                assignedAt: now,
                appVersion: appVersion
            )
        }
    }
}

nonisolated enum OnboardingPaywallArm: String, Codable {
    case control
    case hardTrial = "hard_trial"
}

nonisolated enum OnboardingPaywallAssignmentSource: String, Codable {
    /// Randomized by the PostHog flag.
    case flag
    /// Flags loaded but the key evaluated to false or an unknown value (kill switch, 0% rollout).
    case flagOff = "flag_off"
    /// The arm was needed before the flag ever returned a value.
    case offlineDefault = "offline_default"
    /// Updater with app state, Keychain trial grant, or active entitlement.
    case excluded
    case debugOverride = "debug_override"
    /// Forced by the App Review link (`pillie://review/onboarding-paywall`).
    case review
}

nonisolated struct OnboardingPaywallAssignment: Codable, Equatable {
    let arm: OnboardingPaywallArm
    let source: OnboardingPaywallAssignmentSource
    let assignedAt: Date
    let appVersion: String

    /// Only flag-randomized installs (and QA overrides) belong in the analysis.
    var isEligible: Bool { source == .flag || source == .debugOverride }
}

/// `pending` is persisted because onboarding writes app state right after first
/// launch, so a relaunch must not re-run the fresh-install eligibility check.
nonisolated enum OnboardingPaywallEnrollment: Codable, Equatable {
    case pending(since: Date)
    case assigned(OnboardingPaywallAssignment)
}

//
//  TrialLengthExperiment.swift
//  Pillie
//

import Foundation

/// How many full days this install's Reverse Trial runs in the trial_length_v1
/// test. Raw values are the PostHog variant keys of the `trial-length` flag.
/// `nonisolated` so the nonisolated Keychain grant store can read it.
nonisolated enum TrialLength: String, Codable {
    case fourteenDays = "control"
    case sevenDays = "seven_days"

    var fullDays: Int {
        switch self {
        case .fourteenDays: 14
        case .sevenDays: 7
        }
    }

    /// The Commerce key for trial copy that names the trial's length. An
    /// active-day install reads "14 active days"; a 7-day install reads the
    /// `.seven_days` variant. Count-only plurals keep `TrialDayRule.copyKey`.
    static func copyKey(_ key: String, rule: TrialDayRule, length: TrialLength) -> String {
        rule == .activeDays ? key + ".active_days" : length.variantKey(key)
    }

    /// The `.seven_days` variant for a 7-day trial. Alone, it suits copy with
    /// no `.active_days` variant, such as the timeline day labels.
    func variantKey(_ key: String) -> String {
        self == .sevenDays ? key + ".seven_days" : key
    }

    /// `copyKey` for this install's rule and stored length.
    @MainActor static func copyKey(_ key: String) -> String {
        let subscription = SubscriptionManager.shared
        return copyKey(key, rule: subscription.trialDayRule, length: subscription.trialLength)
    }
}

struct TrialLengthAssignment: Equatable {
    let length: TrialLength
    /// The length came from the experiment, so the grant counts as exposure.
    let isFromFlag: Bool
}

enum TrialLengthExperiment {
    static let name = "trial_length_v1"
    static let flagKey = "trial-length"

    /// Only a calendar-day install (ENG-242) can enroll: an active-day install
    /// keeps "14 active days". No flag yet, an inactive flag, or an unknown
    /// variant gives 14 days outside the test.
    static func assignment(dayRule: TrialDayRule, flagValue: Any?) -> TrialLengthAssignment {
        guard dayRule == .calendarDays,
              let variant = flagValue as? String,
              let length = TrialLength(rawValue: variant)
        else { return TrialLengthAssignment(length: .fourteenDays, isFromFlag: false) }
        return TrialLengthAssignment(length: length, isFromFlag: true)
    }
}

/// Reads the length for the onboarding grant and reports its exposure. The
/// grant stores the length beside it, so this is read once per install.
enum TrialLengthEnrollment {
    #if DEBUG
    /// QA pin from `?trialLength=` on a debug link. It stands in for the flag
    /// value, so an active-day install still stays at 14 days.
    static let debugOverrideKey = "debug_trial_length"
    #endif

    static func current() -> TrialLengthAssignment {
        let analytics = AnalyticsManager.shared
        guard analytics.isAnalyticsEnabled else {
            return TrialLengthAssignment(length: .fourteenDays, isFromFlag: false)
        }
        var flagValue = analytics.featureFlag(TrialLengthExperiment.flagKey)
        #if DEBUG
        if let pinned = UserDefaults.standard.string(forKey: debugOverrideKey) {
            flagValue = pinned
        }
        #endif
        return TrialLengthExperiment.assignment(
            dayRule: SubscriptionManager.shared.trialDayRule,
            flagValue: flagValue
        )
    }

    /// Call once, after the grant that stored this length was written. Only an
    /// experiment arm is reported, so an install the flag never reached stays
    /// out of the test.
    static func expose(_ assignment: TrialLengthAssignment) {
        guard assignment.isFromFlag else { return }
        let variant = assignment.length.rawValue
        let arm: [String: AnalyticsPropertyValue] = ["exp_trial_length": .string(variant)]
        let analytics = AnalyticsManager.shared
        analytics.captureFeatureFlagCalled(
            TrialLengthExperiment.flagKey,
            response: variant,
            personProperties: arm
        )
        analytics.registerSuperProperties(arm)
        SubscriptionManager.shared.recordTrialLength(assignment.length)
    }
}

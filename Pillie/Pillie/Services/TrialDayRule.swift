//
//  TrialDayRule.swift
//  Pillie
//

import Foundation

/// Which days a Reverse Trial counts (ENG-242), fixed per install the first
/// time this build launches. An install from this release on counts 14
/// calendar days. An install that already existed keeps counting 14
/// hormone-active days, even for a first grant made after the update.
/// `nonisolated` so the nonisolated Keychain grant store can read it.
nonisolated enum TrialDayRule: String, Codable, Equatable {
    case activeDays = "active_days"
    case calendarDays = "calendar_days"

    static let storageKey = "trialDayRule"

    /// A stored rule never changes. Otherwise any sign of an earlier install
    /// (onboarding state or a Keychain grant) keeps the active-day count.
    static func assignment(
        hasExistingAppState: Bool,
        hasTrialGrant: Bool,
        previous: TrialDayRule?
    ) -> TrialDayRule {
        if let previous { return previous }
        return hasExistingAppState || hasTrialGrant ? .activeDays : .calendarDays
    }

    @discardableResult
    static func recordAssignment(
        hasExistingAppState: Bool,
        store: TrialGrantStoring,
        defaults: UserDefaults = .standard
    ) -> TrialDayRule {
        let rule = assignment(
            hasExistingAppState: hasExistingAppState,
            hasTrialGrant: store.loadGrantDate() != nil,
            previous: store.loadDayRule() ?? stored(in: defaults)
        )
        store.saveDayRule(rule)
        defaults.set(rule.rawValue, forKey: storageKey)
        return rule
    }

    /// This install's rule, as `SubscriptionManager` loaded it.
    @MainActor static var current: TrialDayRule { SubscriptionManager.shared.trialDayRule }

    /// The Commerce key for trial copy that names the day count. An active-day
    /// install reads the `.active_days` variant ("14 active days").
    @MainActor static func copyKey(_ key: String) -> String {
        current == .activeDays ? key + ".active_days" : key
    }

    static func stored(in defaults: UserDefaults = .standard) -> TrialDayRule? {
        defaults.string(forKey: storageKey).flatMap(TrialDayRule.init(rawValue:))
    }
}

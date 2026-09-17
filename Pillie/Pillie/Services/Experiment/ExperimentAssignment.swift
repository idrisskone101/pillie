import Foundation

enum ExperimentKey: String, CaseIterable {
    case paywallPresentation = "paywall-presentation"
}

enum ExperimentVariant: String, CaseIterable {
    case control
    case test

    static func parse(_ raw: String?) -> ExperimentVariant {
        switch raw {
        case "test", "true":
            return .test
        default:
            return .control
        }
    }
}

enum ExperimentAssignmentSource: String {
    case posthog
    case debugOverride = "debug_override"
    case fallback
}

struct ExperimentAssignment: Equatable {
    let key: ExperimentKey
    let variant: ExperimentVariant
    let source: ExperimentAssignmentSource
}

enum PaywallEngine: String {
    case honest
    case hosted
}

enum CommerceOfferingIdentifier: String, CaseIterable {
    case `default` = "default"
    case defaultV2 = "default_v2"
    case paywallTest = "paywall_test"
    case unknown

    static func parse(_ raw: String?) -> CommerceOfferingIdentifier {
        guard let raw, let match = CommerceOfferingIdentifier(rawValue: raw) else {
            return .unknown
        }
        return match
    }
}

struct CommerceOfferingAssignment: Equatable {
    var identifier: CommerceOfferingIdentifier
    var hasHostedPaywall: Bool

    static let unresolved = CommerceOfferingAssignment(
        identifier: .unknown,
        hasHostedPaywall: false
    )
}

struct ExperimentTelemetryContext: Equatable {
    let key: ExperimentKey
    let variant: ExperimentVariant
    let offering: CommerceOfferingIdentifier
    let engine: PaywallEngine

    var properties: [String: AnalyticsPropertyValue] {
        [
            "experiment_key": .string(key.rawValue),
            "experiment_variant": .string(variant.rawValue),
            "rc_offering": .string(offering.rawValue),
            "paywall_engine": .string(engine.rawValue),
        ]
    }

    static func make(
        assignment: ExperimentAssignment,
        offering: CommerceOfferingAssignment
    ) -> ExperimentTelemetryContext {
        ExperimentTelemetryContext(
            key: assignment.key,
            variant: assignment.variant,
            offering: offering.identifier,
            engine: PaywallPresentationPolicy.engine(
                assignment: assignment,
                offeringHasHostedPaywall: offering.hasHostedPaywall
            )
        )
    }
}

enum ExperimentResolver {
    static func assignment(
        key: ExperimentKey,
        remoteValue: String?,
        overrideValue: String?
    ) -> ExperimentAssignment {
        if let overrideValue {
            return ExperimentAssignment(
                key: key,
                variant: .parse(overrideValue),
                source: .debugOverride
            )
        }
        if let remoteValue {
            return ExperimentAssignment(
                key: key,
                variant: .parse(remoteValue),
                source: .posthog
            )
        }
        return ExperimentAssignment(key: key, variant: .control, source: .fallback)
    }
}

enum PaywallPresentationPolicy {
    static func engine(
        assignment: ExperimentAssignment,
        offeringHasHostedPaywall: Bool
    ) -> PaywallEngine {
        if assignment.variant == .test && offeringHasHostedPaywall {
            return .hosted
        }
        return .honest
    }

    static func preferredOfferingIdentifier(
        assignment: ExperimentAssignment,
        override: CommerceOfferingIdentifier?
    ) -> CommerceOfferingIdentifier? {
        if let override {
            return override
        }
        if assignment.variant == .test {
            return .paywallTest
        }
        return nil
    }
}

enum HostedPaywallAvailability {
    static func isPresent(hasLegacyPaywall: Bool, hasComponents: Bool) -> Bool {
        hasLegacyPaywall || hasComponents
    }
}

enum CommerceOfferingResolver {
    static func selectedIdentifier(
        preferred: CommerceOfferingIdentifier?,
        available: Set<CommerceOfferingIdentifier>,
        current: CommerceOfferingIdentifier
    ) -> CommerceOfferingIdentifier {
        if let preferred, preferred != .unknown, available.contains(preferred) {
            return preferred
        }
        return current
    }
}

enum ExperimentOverrideStore {
    static let variantPrefix = "pillie.debug.experiment."
    static let offeringKey = "pillie.debug.experiment.offering"

    static func variantRawValue(
        for key: ExperimentKey,
        defaults: UserDefaults = .standard
    ) -> String? {
        let value = defaults.string(forKey: storageKey(for: key))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func setVariant(
        _ variant: ExperimentVariant?,
        for key: ExperimentKey,
        defaults: UserDefaults = .standard
    ) {
        if let variant {
            defaults.set(variant.rawValue, forKey: storageKey(for: key))
        } else {
            defaults.removeObject(forKey: storageKey(for: key))
        }
    }

    static func preferredOffering(
        defaults: UserDefaults = .standard
    ) -> CommerceOfferingIdentifier? {
        let raw = defaults.string(forKey: offeringKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        let parsed = CommerceOfferingIdentifier.parse(raw)
        return parsed == .unknown ? nil : parsed
    }

    static func setPreferredOffering(
        _ identifier: CommerceOfferingIdentifier?,
        defaults: UserDefaults = .standard
    ) {
        if let identifier, identifier != .unknown {
            defaults.set(identifier.rawValue, forKey: offeringKey)
        } else {
            defaults.removeObject(forKey: offeringKey)
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        for key in ExperimentKey.allCases {
            defaults.removeObject(forKey: storageKey(for: key))
        }
        defaults.removeObject(forKey: offeringKey)
    }

    static func storageKey(for key: ExperimentKey) -> String {
        variantPrefix + key.rawValue
    }
}

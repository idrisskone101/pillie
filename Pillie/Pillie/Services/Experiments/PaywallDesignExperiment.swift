//
//  PaywallDesignExperiment.swift
//  Pillie
//

import Foundation

/// The honest paywall's look in the paywall_design_v1 test. Raw values are the
/// PostHog variant keys of the `paywall-design` flag.
enum PaywallDesign: String {
    /// The S3 sheet-over-phone paywall (PR #383).
    case s3 = "control"
    /// The paywall main shipped before PR #383.
    case classic
}

struct PaywallDesignAssignment: Equatable {
    let design: PaywallDesign
    /// The arm came from the experiment, so a paywall view counts as exposure.
    let isFromFlag: Bool
}

enum PaywallDesignExperiment {
    static let name = "paywall_design_v1"
    static let flagKey = "paywall-design"

    /// A stored arm always wins. A flag variant becomes the arm, and the caller
    /// stores it. Anything else (no flag yet, experiment not launched, unknown
    /// variant) shows S3 without storing, so the install can still enroll later.
    static func assignment(stored: PaywallDesign?, flagValue: Any?) -> PaywallDesignAssignment {
        if let stored {
            return PaywallDesignAssignment(design: stored, isFromFlag: true)
        }
        if let variant = flagValue as? String, let design = PaywallDesign(rawValue: variant) {
            return PaywallDesignAssignment(design: design, isFromFlag: true)
        }
        return PaywallDesignAssignment(design: .s3, isFromFlag: false)
    }
}

/// This install's arm, kept once the flag has assigned one.
struct PaywallDesignStore {
    static let key = "paywall_design_v1_arm"

    var defaults: UserDefaults = .standard

    func load() -> PaywallDesign? {
        defaults.string(forKey: Self.key).flatMap(PaywallDesign.init(rawValue:))
    }

    func save(_ design: PaywallDesign) {
        defaults.set(design.rawValue, forKey: Self.key)
    }
}

/// Reads the arm for a paywall presentation and reports its exposure.
enum PaywallDesignEnrollment {
    static func current(store: PaywallDesignStore = PaywallDesignStore()) -> PaywallDesignAssignment {
        let analytics = AnalyticsManager.shared
        guard analytics.isAnalyticsEnabled else {
            return PaywallDesignAssignment(design: .s3, isFromFlag: false)
        }
        return PaywallDesignExperiment.assignment(
            stored: store.load(),
            flagValue: analytics.featureFlag(PaywallDesignExperiment.flagKey)
        )
    }

    /// Call once per paywall presentation. Only an experiment arm is stored and
    /// reported, so an install the flag has not reached stays out of the test.
    static func expose(_ assignment: PaywallDesignAssignment, store: PaywallDesignStore = PaywallDesignStore()) {
        guard assignment.isFromFlag else { return }
        if store.load() == nil {
            store.save(assignment.design)
        }
        let variant = assignment.design.rawValue
        let arm: [String: AnalyticsPropertyValue] = ["exp_paywall_design": .string(variant)]
        let analytics = AnalyticsManager.shared
        analytics.captureFeatureFlagCalled(
            PaywallDesignExperiment.flagKey,
            response: variant,
            personProperties: arm
        )
        analytics.registerSuperProperties(arm)
        SubscriptionManager.shared.recordPaywallDesign(assignment.design)
    }
}

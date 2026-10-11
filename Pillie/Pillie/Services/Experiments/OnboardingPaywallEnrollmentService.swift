//
//  OnboardingPaywallEnrollmentService.swift
//  Pillie
//

import Foundation
import os

/// Owns this install's onboarding paywall arm (ENG-205): enrolls at launch, reads the
/// PostHog flag at most once, and tags PostHog, RevenueCat and AppsFlyer with the arm.
@MainActor
final class OnboardingPaywallEnrollmentService {
    static let shared = OnboardingPaywallEnrollmentService()

    private let store: OnboardingPaywallEnrollmentStoring
    private let analytics = AnalyticsManager.shared
    private let log = Logger(subsystem: "com.idrisskone.pillie", category: "experiment")

    init(store: OnboardingPaywallEnrollmentStoring = KeychainOnboardingPaywallEnrollmentStore()) {
        self.store = store
    }

    /// Call once per launch, after analytics and RevenueCat are configured, with app
    /// state read before this launch writes any.
    func start(hasExistingAppState: Bool, hasTrialGrant: Bool) {
        let enrollment = OnboardingPaywallExperiment.enrollment(
            stored: store.load(),
            hasExistingAppState: hasExistingAppState,
            hasTrialGrant: hasTrialGrant,
            now: Date(),
            appVersion: Self.appVersion
        )
        store.save(enrollment)
        switch enrollment {
        case .assigned(let assignment):
            publish(assignment)
        case .pending:
            log.notice("onboarding_paywall enrollment=pending")
            Task { await resolvePending() }
        }
    }

    /// Fixes the arm the moment the onboarding paywall arms diverge. A still-pending
    /// install falls back to control so the flag can never flip it mid-onboarding.
    @discardableResult
    func lockArm() -> OnboardingPaywallArm {
        // Nothing stored means `start` never ran (hosted tests), so there is no arm to fix.
        guard let enrollment = store.load() else { return .control }
        let assignment = OnboardingPaywallExperiment.lockedAssignment(
            enrollment,
            now: Date(),
            appVersion: Self.appVersion
        )
        if case .pending = enrollment {
            assign(assignment)
        }
        return assignment.arm
    }

    private func resolvePending() async {
        // An active subscriber reinstalling has no Keychain grant but must stay out.
        await SubscriptionManager.shared.refreshStatus()
        guard isPending else { return }
        let subscription = SubscriptionManager.shared
        if subscription.hasResolvedEntitlement, subscription.hasEntitlement {
            assign(OnboardingPaywallAssignment(
                arm: .control,
                source: .excluded,
                assignedAt: Date(),
                appVersion: Self.appVersion
            ))
            return
        }
        analytics.reloadFeatureFlags { [weak self] in
            self?.readFlagIfPending()
        }
    }

    private func readFlagIfPending() {
        guard isPending else { return }
        guard let assignment = OnboardingPaywallExperiment.assignment(
            forFlagValue: analytics.featureFlag(OnboardingPaywallExperiment.flagKey),
            now: Date(),
            appVersion: Self.appVersion
        ) else {
            log.notice("onboarding_paywall enrollment=pending flag=unavailable")
            return
        }
        assign(assignment)
    }

    private var isPending: Bool {
        if case .pending = store.load() { return true }
        return false
    }

    private func assign(_ assignment: OnboardingPaywallAssignment) {
        store.save(.assigned(assignment))
        publish(assignment)
    }

    private func publish(_ assignment: OnboardingPaywallAssignment) {
        analytics.registerSuperProperties([
            "experiment_name": .string(OnboardingPaywallExperiment.experimentName),
            "experiment_variant": .string(assignment.arm.rawValue),
            "experiment_eligible": .bool(assignment.isEligible),
            "experiment_assignment_source": .string(assignment.source.rawValue),
        ])
        analytics.setPersonProperties(["onboarding_paywall_arm": .string(assignment.arm.rawValue)])
        SubscriptionManager.shared.recordOnboardingPaywallArm(assignment.arm)
        AppsFlyerManager.shared.setOnboardingPaywallArm(assignment.arm)
        log.notice(
            "onboarding_paywall enrollment=assigned arm=\(assignment.arm.rawValue, privacy: .public) source=\(assignment.source.rawValue, privacy: .public) eligible=\(assignment.isEligible, privacy: .public)"
        )
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    #if DEBUG
    /// QA control: `nil` forgets the enrollment so the next launch enrolls afresh.
    func debugOverride(_ arm: OnboardingPaywallArm?) {
        guard let arm else {
            store.clear()
            analytics.unregisterSuperProperties([
                "experiment_name",
                "experiment_variant",
                "experiment_eligible",
                "experiment_assignment_source",
            ])
            log.notice("onboarding_paywall enrollment=cleared")
            return
        }
        assign(OnboardingPaywallAssignment(
            arm: arm,
            source: .debugOverride,
            assignedAt: Date(),
            appVersion: Self.appVersion
        ))
    }
    #endif
}

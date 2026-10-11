//
//  OnboardingPaywallExperimentTests.swift
//  PillieTests
//
//  ENG-205: who enters the onboarding paywall experiment, how the PostHog flag maps
//  to an arm, and the store contract. Value types and nonisolated stores only, since
//  the Xcode 27 beta hosted runner crashes deallocating @MainActor classes.
//

import Foundation
import Testing

@testable import Pillie

struct OnboardingPaywallExperimentTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let later = Date(timeIntervalSince1970: 1_790_086_400)

    private func assignment(
        _ arm: OnboardingPaywallArm,
        _ source: OnboardingPaywallAssignmentSource,
        at date: Date? = nil
    ) -> OnboardingPaywallAssignment {
        OnboardingPaywallAssignment(arm: arm, source: source, assignedAt: date ?? now, appVersion: "2.3")
    }

    private func enrollment(
        stored: OnboardingPaywallEnrollment? = nil,
        appState: Bool = false,
        grant: Bool = false
    ) -> OnboardingPaywallEnrollment {
        OnboardingPaywallExperiment.enrollment(
            stored: stored,
            hasExistingAppState: appState,
            hasTrialGrant: grant,
            now: now,
            appVersion: "2.3"
        )
    }

    // MARK: - Eligibility

    @Test func freshInstallWaitsForTheFlag() {
        #expect(enrollment() == .pending(since: now))
    }

    @Test func reinstallWithAKeychainGrantIsExcludedToControl() {
        #expect(enrollment(grant: true) == .assigned(assignment(.control, .excluded)))
    }

    @Test func updaterWithAppStateIsExcludedToControl() {
        #expect(enrollment(appState: true) == .assigned(assignment(.control, .excluded)))
    }

    @Test func storedAssignmentIsNeverReRolled() {
        let stored = OnboardingPaywallEnrollment.assigned(assignment(.hardTrial, .flag, at: later))
        #expect(enrollment(stored: stored, appState: true, grant: true) == stored)
    }

    @Test func storedPendingStaysPendingOnceOnboardingHasStarted() {
        let stored = OnboardingPaywallEnrollment.pending(since: later)
        #expect(enrollment(stored: stored, appState: true) == .pending(since: later))
    }

    // MARK: - Flag mapping

    @Test func flagVariantsMapToArms() {
        let map = { (value: Any?) in
            OnboardingPaywallExperiment.assignment(forFlagValue: value, now: self.now, appVersion: "2.3")
        }
        #expect(map("hard_trial") == assignment(.hardTrial, .flag))
        #expect(map("control") == assignment(.control, .flag))
        #expect(map(nil) == nil)
        #expect(map(false) == assignment(.control, .flagOff))
        #expect(map("garbage") == assignment(.control, .flagOff))
    }

    // MARK: - Lock

    @Test func lockingAPendingInstallFallsBackToControl() {
        let locked = OnboardingPaywallExperiment.lockedAssignment(
            .pending(since: later),
            now: now,
            appVersion: "2.3"
        )
        #expect(locked == assignment(.control, .offlineDefault))
    }

    @Test func lockingAnAssignedInstallKeepsItsArm() {
        let assigned = assignment(.hardTrial, .flag, at: later)
        let locked = OnboardingPaywallExperiment.lockedAssignment(
            .assigned(assigned),
            now: now,
            appVersion: "2.4"
        )
        #expect(locked == assigned)
    }

    @Test func onlyRandomizedInstallsAreEligible() {
        #expect(assignment(.hardTrial, .flag).isEligible == true)
        #expect(assignment(.hardTrial, .debugOverride).isEligible == true)
        #expect(assignment(.control, .flagOff).isEligible == false)
        #expect(assignment(.control, .offlineDefault).isEligible == false)
        #expect(assignment(.control, .excluded).isEligible == false)
    }

    // MARK: - Store contract

    @Test func inMemoryStoreHonorsTheContract() {
        assertStoreContract(InMemoryOnboardingPaywallEnrollmentStore())
    }

    @Test func keychainStoreHonorsTheContract() {
        assertStoreContract(KeychainOnboardingPaywallEnrollmentStore())
    }

    private func assertStoreContract(_ store: OnboardingPaywallEnrollmentStoring) {
        defer { store.clear() }
        store.clear()
        #expect(store.load() == nil)

        store.save(.pending(since: now))
        #expect(store.load() == .pending(since: now))

        let assigned = OnboardingPaywallEnrollment.assigned(assignment(.hardTrial, .flag, at: later))
        store.save(assigned)
        #expect(store.load() == assigned)

        store.clear()
        #expect(store.load() == nil)
    }
}

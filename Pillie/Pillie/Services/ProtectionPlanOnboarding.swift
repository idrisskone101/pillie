//
//  ProtectionPlanOnboarding.swift
//  Pillie
//
//  Deep, UI-free state model for the Protection Plan Onboarding flow (PRD #72).
//  The flow's logic lives in value types (`ProtectionPlanOnboardingState` +
//  `ProtectionPlanOnboardingStore`) so it is fully unit-testable without any
//  reference-type / main-actor deinit hazards. `ProtectionPlanOnboardingModel`
//  is a thin `@Observable` wrapper used by SwiftUI; it forwards to the value core
//  and persists on every mutation.
//

import Foundation

/// The locked high-level order from ADR `0003-protection-plan-onboarding`.
///
/// Raw values are stable and persisted, so new cases must only ever be appended.
/// Only `welcome` and `analyticsConsent` are rendered in the first vertical slice;
/// the remaining cases reserve the routing order for later slices.
enum ProtectionPlanStep: Int, CaseIterable {
    case welcome = 0
    case analyticsConsent = 1
    case earlyValueProof = 2
    case reviewPrompt = 3
    case distractionChoices = 4
    case delayConsequence = 5
    case failureFrequency = 6
    case riskWindow = 7
    case draftBlockedApps = 8
    case acquisitionSource = 9
    case routineBasics = 10
    case reminderTime = 11
    case diagnosis = 12
    case mechanismProof = 13
    case paywall = 14

    /// The first step a brand-new user sees.
    static let first: ProtectionPlanStep = .welcome

    /// The next step in the locked order, or `nil` once the flow runs past the
    /// final modeled step.
    var next: ProtectionPlanStep? {
        ProtectionPlanStep(rawValue: rawValue + 1)
    }

    /// The previous step in the locked order, or `nil` at the first step.
    var previous: ProtectionPlanStep? {
        ProtectionPlanStep(rawValue: rawValue - 1)
    }
}

/// The user's committed Analytics Consent answer. Kept separate from the live
/// `AnalyticsManager` opt-out flag so back navigation can restore the previous
/// selection without re-toggling capture.
enum AnalyticsConsentDecision: String, Equatable {
    case undecided
    case allowed
    case declined
}

/// The committed onboarding state: the current step plus the answers collected so
/// far. A value type with pure mutating transitions — the deep, testable core.
struct ProtectionPlanOnboardingState: Equatable {
    private(set) var currentStep: ProtectionPlanStep
    private(set) var analyticsConsentDecision: AnalyticsConsentDecision

    init(
        currentStep: ProtectionPlanStep = .first,
        analyticsConsentDecision: AnalyticsConsentDecision = .undecided
    ) {
        self.currentStep = currentStep
        self.analyticsConsentDecision = analyticsConsentDecision
    }

    /// Whether the user can step backward from the current step.
    var canGoBack: Bool {
        currentStep.previous != nil
    }

    /// Whether the screens the new shell owns — Welcome, Analytics Consent, and the
    /// Early Value Proof — have all been completed, signalling the handoff into the
    /// preserved Review Prompt and the rest of onboarding. The new-flow `reviewPrompt`
    /// step acts as that handoff sentinel.
    var hasFinishedIntro: Bool {
        currentStep.rawValue > ProtectionPlanStep.earlyValueProof.rawValue
    }

    /// Records the Analytics Consent answer as a committed onboarding answer.
    mutating func recordAnalyticsConsent(allowed: Bool) {
        analyticsConsentDecision = allowed ? .allowed : .declined
    }

    /// Commits the current step and moves forward in the locked order.
    mutating func advance() {
        guard let next = currentStep.next else { return }
        currentStep = next
    }

    /// Steps backward while preserving every committed answer.
    mutating func goBack() {
        guard let previous = currentStep.previous else { return }
        currentStep = previous
    }
}

/// Pure persistence for `ProtectionPlanOnboardingState` over an injectable
/// `UserDefaults`, so committed progress survives app interruption.
enum ProtectionPlanOnboardingStore {
    enum Keys {
        static let step = "protectionPlanOnboardingStep"
        static let consent = "protectionPlanOnboardingAnalyticsConsent"
    }

    static func load(from defaults: UserDefaults) -> ProtectionPlanOnboardingState {
        let step = (defaults.object(forKey: Keys.step) as? Int)
            .flatMap(ProtectionPlanStep.init(rawValue:)) ?? .first
        let consent = defaults.string(forKey: Keys.consent)
            .flatMap(AnalyticsConsentDecision.init(rawValue:)) ?? .undecided
        return ProtectionPlanOnboardingState(
            currentStep: step,
            analyticsConsentDecision: consent
        )
    }

    static func save(_ state: ProtectionPlanOnboardingState, to defaults: UserDefaults) {
        defaults.set(state.currentStep.rawValue, forKey: Keys.step)
        defaults.set(state.analyticsConsentDecision.rawValue, forKey: Keys.consent)
    }
}

/// Thin `@Observable` wrapper around the value core for SwiftUI. Lives for the
/// onboarding session (created once in `ContentView`), so it is never rapidly
/// deallocated the way a unit-test loop would. All behavior is delegated to the
/// value types above, which carry the test coverage.
@Observable
final class ProtectionPlanOnboardingModel {
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var state: ProtectionPlanOnboardingState

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = ProtectionPlanOnboardingStore.load(from: defaults)
    }

    var currentStep: ProtectionPlanStep { state.currentStep }
    var analyticsConsentDecision: AnalyticsConsentDecision { state.analyticsConsentDecision }
    var canGoBack: Bool { state.canGoBack }
    var hasFinishedIntro: Bool { state.hasFinishedIntro }

    func recordAnalyticsConsent(allowed: Bool) {
        state.recordAnalyticsConsent(allowed: allowed)
        persist()
    }

    func advance() {
        state.advance()
        persist()
    }

    func goBack() {
        state.goBack()
        persist()
    }

    private func persist() {
        ProtectionPlanOnboardingStore.save(state, to: defaults)
    }
}

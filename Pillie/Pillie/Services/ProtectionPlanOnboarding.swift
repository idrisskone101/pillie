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
/// `analyticsConsent` is retired and never rendered — it is retained only so
/// persisted step values migrate forward (see `ProtectionPlanOnboardingStore`).
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
        // Analytics Consent was retired — Welcome leads straight to the Early Value
        // Proof (analytics is collected for everyone, with no consent screen).
        if self == .welcome { return .earlyValueProof }
        return ProtectionPlanStep(rawValue: rawValue + 1)
    }

    /// The previous step in the locked order, or `nil` at the first step.
    var previous: ProtectionPlanStep? {
        if self == .earlyValueProof { return .welcome }   // Analytics Consent retired.
        return ProtectionPlanStep(rawValue: rawValue - 1)
    }
}

/// The committed onboarding state: the current step plus the answers collected so
/// far. A value type with pure mutating transitions — the deep, testable core.
struct ProtectionPlanOnboardingState: Equatable {
    private(set) var currentStep: ProtectionPlanStep
    /// Committed Distraction Choices (multi-select, includes Other). Empty until
    /// the user commits the answer on the Distraction Choices screen.
    private(set) var distractionChoices: Set<DistractionChoice>
    /// Committed Delay Consequence (single-select), or `nil` until answered.
    private(set) var delayConsequence: DelayConsequence?
    /// Committed Risk Window (single-select), or `nil` until answered. Copy /
    /// personalization only in v1 — never used to change the blocking schedule.
    private(set) var riskWindow: RiskWindow?
    /// Committed Draft Blocked App Choices (multi-select, grouped, includes Other).
    /// A draft intent only — kept separate from the real Screen Time selection.
    private(set) var draftBlockedApps: Set<DraftBlockedAppChoice>

    init(
        currentStep: ProtectionPlanStep = .first,
        distractionChoices: Set<DistractionChoice> = [],
        delayConsequence: DelayConsequence? = nil,
        riskWindow: RiskWindow? = nil,
        draftBlockedApps: Set<DraftBlockedAppChoice> = []
    ) {
        self.currentStep = currentStep
        self.distractionChoices = distractionChoices
        self.delayConsequence = delayConsequence
        self.riskWindow = riskWindow
        self.draftBlockedApps = draftBlockedApps
    }

    /// Whether the user can step backward from the current step.
    var canGoBack: Bool {
        currentStep.previous != nil
    }

    /// Whether the screens the new shell owns — Welcome and the Early Value Proof —
    /// have all been completed, signalling the handoff into the rest of onboarding.
    /// The `reviewPrompt` step is retained only as that handoff sentinel; the review
    /// request screen itself was removed.
    var hasFinishedIntro: Bool {
        currentStep.rawValue > ProtectionPlanStep.earlyValueProof.rawValue
    }

    /// Commits the multi-select Distraction Choices answer, replacing any prior
    /// selection.
    mutating func recordDistractionChoices(_ choices: Set<DistractionChoice>) {
        distractionChoices = choices
    }

    /// Commits the single-select Delay Consequence answer.
    mutating func recordDelayConsequence(_ consequence: DelayConsequence?) {
        delayConsequence = consequence
    }

    /// Commits the single-select Risk Window answer.
    mutating func recordRiskWindow(_ window: RiskWindow?) {
        riskWindow = window
    }

    /// Commits the multi-select Draft Blocked App Choices answer, replacing any
    /// prior selection.
    mutating func recordDraftBlockedApps(_ choices: Set<DraftBlockedAppChoice>) {
        draftBlockedApps = choices
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
        static let distractionChoices = "protectionPlanOnboardingDistractionChoices"
        static let delayConsequence = "protectionPlanOnboardingDelayConsequence"
        static let riskWindow = "protectionPlanOnboardingRiskWindow"
        static let draftBlockedApps = "protectionPlanOnboardingDraftBlockedApps"
    }

    static func load(from defaults: UserDefaults) -> ProtectionPlanOnboardingState {
        let loadedStep = (defaults.object(forKey: Keys.step) as? Int)
            .flatMap(ProtectionPlanStep.init(rawValue:)) ?? .first
        // Analytics Consent was retired; migrate anyone persisted on it forward to
        // the Early Value Proof so they never land on the removed screen.
        let step = loadedStep == .analyticsConsent ? .earlyValueProof : loadedStep
        let distractionChoices = Set(
            (defaults.stringArray(forKey: Keys.distractionChoices) ?? [])
                .compactMap(DistractionChoice.init(rawValue:))
        )
        let delayConsequence = defaults.string(forKey: Keys.delayConsequence)
            .flatMap(DelayConsequence.init(rawValue:))
        let riskWindow = defaults.string(forKey: Keys.riskWindow)
            .flatMap(RiskWindow.init(rawValue:))
        let draftBlockedApps = Set(
            (defaults.stringArray(forKey: Keys.draftBlockedApps) ?? [])
                .compactMap(DraftBlockedAppChoice.init(rawValue:))
        )
        return ProtectionPlanOnboardingState(
            currentStep: step,
            distractionChoices: distractionChoices,
            delayConsequence: delayConsequence,
            riskWindow: riskWindow,
            draftBlockedApps: draftBlockedApps
        )
    }

    static func save(_ state: ProtectionPlanOnboardingState, to defaults: UserDefaults) {
        defaults.set(state.currentStep.rawValue, forKey: Keys.step)
        defaults.set(state.distractionChoices.map(\.rawValue), forKey: Keys.distractionChoices)
        if let delayConsequence = state.delayConsequence {
            defaults.set(delayConsequence.rawValue, forKey: Keys.delayConsequence)
        } else {
            defaults.removeObject(forKey: Keys.delayConsequence)
        }
        if let riskWindow = state.riskWindow {
            defaults.set(riskWindow.rawValue, forKey: Keys.riskWindow)
        } else {
            defaults.removeObject(forKey: Keys.riskWindow)
        }
        defaults.set(state.draftBlockedApps.map(\.rawValue), forKey: Keys.draftBlockedApps)
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

    /// True once the diagnosis reveal ("building your protection plan") has played
    /// this session. Returning to the plan — e.g. Back from the paywall — then shows
    /// the finished plan immediately instead of replaying the loading animation.
    /// In-memory only: a fresh launch replays the reveal.
    @ObservationIgnored var hasRevealedDiagnosisPlan = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = ProtectionPlanOnboardingStore.load(from: defaults)
    }

    var currentStep: ProtectionPlanStep { state.currentStep }
    var distractionChoices: Set<DistractionChoice> { state.distractionChoices }
    var delayConsequence: DelayConsequence? { state.delayConsequence }
    var riskWindow: RiskWindow? { state.riskWindow }
    var draftBlockedApps: Set<DraftBlockedAppChoice> { state.draftBlockedApps }
    var canGoBack: Bool { state.canGoBack }
    var hasFinishedIntro: Bool { state.hasFinishedIntro }

    func recordDistractionChoices(_ choices: Set<DistractionChoice>) {
        state.recordDistractionChoices(choices)
        persist()
    }

    func recordDelayConsequence(_ consequence: DelayConsequence?) {
        state.recordDelayConsequence(consequence)
        persist()
    }

    func recordRiskWindow(_ window: RiskWindow?) {
        state.recordRiskWindow(window)
        persist()
    }

    func recordDraftBlockedApps(_ choices: Set<DraftBlockedAppChoice>) {
        state.recordDraftBlockedApps(choices)
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

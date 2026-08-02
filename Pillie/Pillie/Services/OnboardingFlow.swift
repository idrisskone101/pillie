//
//  OnboardingFlow.swift
//  Pillie
//

import Foundation

enum OnboardingCompletionRoute: Equatable {
    case complete
    case awaitingCommerceResolution
    case hardPaywall

    static func resolve(
        state: PlusAccessState,
        termsCohort: TrialTermsCohort,
        hardPaywallEnabled: Bool,
        entitlementResolved: Bool,
        configurationResolved: Bool,
        calendar: Calendar,
        now: Date
    ) -> OnboardingCompletionRoute {
        if state.hasEntitlement || state.trialActive(calendar: calendar, now: now) {
            return .complete
        }
        guard state.trialGrantDate != nil else { return .complete }
        guard termsCohort == .postCutover else { return .complete }
        if configurationResolved, !hardPaywallEnabled {
            return .complete
        }
        guard entitlementResolved, configurationResolved else {
            return .awaitingCommerceResolution
        }
        return HardPaywallPolicy.terms(
            for: termsCohort,
            hardPaywallEnabled: hardPaywallEnabled
        ) == .hardPaywall ? .hardPaywall : .complete
    }
}

enum RootCommerceGate: Equatable {
    case app
    case verifyingAccess

    static func resolve(
        state: PlusAccessState,
        termsCohort: TrialTermsCohort,
        hardPaywallEnabled: Bool,
        entitlementResolved: Bool,
        configurationResolved: Bool,
        calendar: Calendar,
        now: Date
    ) -> RootCommerceGate {
        switch OnboardingCompletionRoute.resolve(
            state: state,
            termsCohort: termsCohort,
            hardPaywallEnabled: hardPaywallEnabled,
            entitlementResolved: entitlementResolved,
            configurationResolved: configurationResolved,
            calendar: calendar,
            now: now
        ) {
        case .awaitingCommerceResolution:
            return .verifyingAccess
        case .complete, .hardPaywall:
            return .app
        }
    }
}

struct CommerceResolutionAttempt: Equatable {
    private(set) var isResolving = false

    mutating func begin() -> Bool {
        guard !isResolving else { return false }
        isResolving = true
        return true
    }

    mutating func finish() {
        isResolving = false
    }
}

enum OnboardingTrialActivationRoute: Equatable {
    case verifyingAccess
    case subscriber
    case grantTrial

    static func resolve(
        hasEntitlement: Bool,
        entitlementResolved: Bool,
        configurationResolved: Bool
    ) -> OnboardingTrialActivationRoute {
        guard entitlementResolved, configurationResolved else {
            return .verifyingAccess
        }
        return hasEntitlement ? .subscriber : .grantTrial
    }

    static func shouldGrantTrial(
        after previous: OnboardingTrialActivationRoute,
        current: OnboardingTrialActivationRoute
    ) -> Bool {
        previous != current && current == .grantTrial
    }
}

#if DEBUG
struct OnboardingHardPaywallDebugScenario: Equatable {
    let grantDate: Date
    let termsCohort: TrialTermsCohort

    static func make(
        expired: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> OnboardingHardPaywallDebugScenario {
        let grantDate = expired
            ? calendar.date(byAdding: .day, value: -16, to: now) ?? now
            : now
        return OnboardingHardPaywallDebugScenario(
            grantDate: grantDate,
            termsCohort: .postCutover
        )
    }
}
#endif

enum OnboardingFlow {
    static let stepStorageKey = "onboardingStep"
    static let selectedFreePlanStorageKey = "onboardingSelectedFreePlan"

    enum Step: Int, CaseIterable {
        case welcome = 0
        case analyticsConsent = 1
        case productDemo = 2
        case plusBlockingDemo = 3
        // Retired: the in-onboarding review request was removed. The case (and its
        // raw value) is retained so persisted `onboardingStep` values are never
        // reinterpreted; it is dropped from `displayOrder` and `visibleStep` maps it
        // forward to `.painPoints`, so it is never rendered.
        case reviewPrompt = 4
        case painPoints = 5
        case goal = 6
        case missFrequency = 7
        case acquisitionSource = 8
        case method = 9
        case schedule = 10
        case reminderTime = 11
        case reminderPlan = 12
        case paywall = 13
        case freePlanConfirmation = 14
        case appBlocking = 15
        case complete = 16
        // Calibration steps added by issue #76. Appended (not renumbered) so the
        // original persisted raw values are never reinterpreted; their position in
        // the flow is expressed by `displayOrder`, not by raw-value magnitude.
        case riskWindow = 17
        // Retired: the "which apps should Pillie block" draft question was removed —
        // the diagnosis now derives the plan from the Distraction Choices answer. The
        // case (and raw value) is retained so persisted `onboardingStep` values are
        // never reinterpreted; it is dropped from `displayOrder` and `visibleStep`
        // migrates it forward to `.acquisitionSource`, so it is never rendered.
        case draftBlockedApps = 18
        // Mechanism Proof added by issue #78. Appended for the same reason; it sits
        // between the diagnosis reveal (`reminderPlan` slot) and the paywall.
        case mechanismProof = 19
        // Pill Protection Plan Ready added by issue #83. Appended for the same reason;
        // it is the terminal activation screen shown after a valid blocker config save,
        // sitting between `appBlocking` and `complete`.
        case protectionPlanReady = 20
        // Trial Granted Moment added by issue #164 (ADR 0007). Appended for the same
        // reason; it replaces the retired paywall at the old paywall position —
        // a non-purchase announcement that the Reverse Trial has started.
        case trialGranted = 21

        var analyticsStep: AnalyticsStep? {
            switch self {
            case .welcome: return .welcome
            case .analyticsConsent: return .analyticsConsent
            case .productDemo: return .productDemo
            case .plusBlockingDemo: return .plusBlockingDemo
            case .reviewPrompt: return .reviewPrompt
            case .painPoints: return .painPoints
            case .goal: return .goal
            case .missFrequency: return .missFrequency
            case .acquisitionSource: return .acquisitionSource
            case .method: return .method
            case .schedule: return .schedule
            case .reminderTime: return .reminderTime
            case .reminderPlan: return .reminderPlan
            case .paywall: return .paywall
            case .freePlanConfirmation: return .freePlanConfirmation
            case .appBlocking: return .appBlocking
            case .complete: return nil
            case .riskWindow: return .riskWindow
            case .draftBlockedApps: return .draftBlockedApps
            case .mechanismProof: return .mechanismProof
            case .protectionPlanReady: return .protectionPlanReady
            case .trialGranted: return .trialGranted
            }
        }
    }

    enum TransitionDirection {
        case forward
        case backward
    }

    struct Transition {
        let from: Step
        let to: Step
        let direction: TransitionDirection
        let completedAnalyticsStep: AnalyticsStep?
        let completesOnboarding: Bool
    }

    static let firstStep: Step = .welcome
    static let finalOnboardingStep: Step = .appBlocking
    static let completedStep: Step = .complete
    static let displayOrder: [Step] = [
        .welcome,
        .productDemo,
        .plusBlockingDemo,
        .analyticsConsent,
        // .reviewPrompt retired: the intro now hands off straight into the questions.
        // Personalization is consolidated into two screens (#207). The original
        // raw values stay frozen for safe resume migration, while the canonical
        // display order keeps only the combined intent and timing steps.
        .painPoints,
        .missFrequency,
        // .draftBlockedApps retired: the diagnosis derives the plan from the
        // Distraction Choices answer, so the draft-blocklist question was removed.
        .acquisitionSource,
        .method,
        .schedule,
        .reminderTime,
        .reminderPlan,
        // .mechanismProof intentionally omitted: the diagnosis reveal now leads
        // straight into app-blocking setup. The step + view are retained but unreachable.
        // .paywall and .freePlanConfirmation retired (issue #164 / ADR 0007): the
        // Reverse Trial replaces the onboarding purchase offer, and issue #204 retires
        // the Trial Granted Moment as a mandatory gate. Everyone proceeds directly
        // into the Screen Time branch.
        .appBlocking,
        // Pill Protection Plan Ready (#83): the terminal activation screen between a
        // valid blocker config save and opening the app.
        .protectionPlanReady,
        .complete,
    ]

    static func step(for rawValue: Int) -> Step? {
        Step(rawValue: rawValue)
    }

    static func analyticsStep(for rawValue: Int) -> AnalyticsStep? {
        step(for: rawValue)?.analyticsStep
    }

    /// The step's 0-based position within `displayOrder` — the funnel `step_index`.
    /// Derived from the canonical render/funnel sequence rather than the frozen raw
    /// value, so it stays monotonic with real progression. Retired steps (dropped
    /// from `displayOrder`) and unknown raw values have no position and return `nil`.
    static func displayIndex(for rawValue: Int) -> Int? {
        guard let step = step(for: rawValue) else { return nil }
        return displayOrder.firstIndex(of: step)
    }

    static func nextStep(after step: Step) -> Step? {
        guard let index = displayOrder.firstIndex(of: step) else { return nil }
        let nextIndex = displayOrder.index(after: index)
        guard nextIndex < displayOrder.endIndex else { return nil }
        return displayOrder[nextIndex]
    }

    static func previousStep(before step: Step) -> Step? {
        guard let index = displayOrder.firstIndex(of: step), index > displayOrder.startIndex else {
            return nil
        }
        return displayOrder[displayOrder.index(before: index)]
    }

    static func grantsReverseTrial(on step: Step) -> Bool {
        step == .appBlocking
    }

    static func visibleStep(for rawValue: Int, isPlus: Bool, selectedFreePlan: Bool) -> Step? {
        guard let step = step(for: rawValue) else { return nil }

        // The review request was retired. Anyone persisted on the old step (or handed
        // off to it) is migrated forward to the first question so they never land on
        // the removed screen.
        if step == .reviewPrompt {
            return .painPoints
        }

        // The former standalone outcome and risk-window questions are now sections
        // of the two consolidated personalization screens. Resume forward so a
        // partially completed onboarding never repeats an earlier question.
        if step == .goal {
            return .missFrequency
        }
        if step == .riskWindow {
            return .acquisitionSource
        }

        // The "which apps to block" draft question was removed; anyone persisted on
        // it (or handed off to it) is migrated forward to the next question.
        if step == .draftBlockedApps {
            return .acquisitionSource
        }

        // The retained Mechanism Proof implementation predates runtime localization
        // and is no longer part of the canonical flow. Resume persisted users at the
        // next live step so they cannot land on an obsolete English-only screen.
        if step == .mechanismProof {
            return .appBlocking
        }

        // The paywall and free-plan confirmation were retired by the Reverse Trial
        // (issue #164 / ADR 0007), and issue #204 retires the Trial Granted Moment as
        // a blocking gate. Anyone persisted on those steps resumes at app-blocking
        // setup, which runs under real Plus Access for everyone.
        if step == .paywall || step == .freePlanConfirmation || step == .trialGranted {
            return .appBlocking
        }

        return step
    }

    static func isOnboardingActive(rawStep: Int) -> Bool {
        // Identity-based rather than a raw-value magnitude check: calibration steps
        // (#76) are appended with raw values above `complete`, but are still active
        // onboarding. Onboarding is active for any real step that is not `complete`.
        guard let step = step(for: rawStep) else { return false }
        return step != completedStep
    }

    static func completedOnboarding(from previousRawStep: Int, to nextRawStep: Int) -> Bool {
        // Onboarding completes exactly when we transition into `complete` from any
        // earlier step. Identity-based so advancing into an appended calibration step
        // (raw value above `complete`) is never mistaken for completion.
        guard let previousStep = step(for: previousRawStep),
              let nextStep = step(for: nextRawStep) else {
            return false
        }
        return previousStep != completedStep && nextStep == completedStep
    }

    static func transition(from previousRawStep: Int, to nextRawStep: Int) -> Transition? {
        guard let previousStep = step(for: previousRawStep),
              let nextStep = step(for: nextRawStep),
              previousStep != nextStep else {
            return nil
        }

        return Transition(
            from: previousStep,
            to: nextStep,
            direction: transitionDirection(from: previousStep, to: nextStep),
            completedAnalyticsStep: previousStep.analyticsStep,
            completesOnboarding: completedOnboarding(from: previousRawStep, to: nextRawStep)
        )
    }

    private static func transitionDirection(from previousStep: Step, to nextStep: Step) -> TransitionDirection {
        guard let previousIndex = displayOrder.firstIndex(of: previousStep),
              let nextIndex = displayOrder.firstIndex(of: nextStep) else {
            return nextStep.rawValue > previousStep.rawValue ? .forward : .backward
        }

        return nextIndex > previousIndex ? .forward : .backward
    }
}

/// Missing-answer defaults for users resumed on one of the two retired standalone
/// personalization steps (#207). Existing committed answers always win.
enum ProtectionPlanPersonalizationMigration {
    struct Answers: Equatable {
        let desiredOutcome: DelayConsequence?
        let riskWindow: RiskWindow?
    }

    static func answersForResume(
        at step: OnboardingFlow.Step,
        desiredOutcome: DelayConsequence?,
        riskWindow: RiskWindow?
    ) -> Answers {
        Answers(
            desiredOutcome: step == .goal ? desiredOutcome ?? .dontCare : desiredOutcome,
            riskWindow: step == .riskWindow ? riskWindow ?? .randomly : riskWindow
        )
    }
}

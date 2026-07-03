//
//  OnboardingFlow.swift
//  Pillie
//

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
        .painPoints,
        .goal,
        .missFrequency,
        .riskWindow,
        // .draftBlockedApps retired: the diagnosis derives the plan from the
        // Distraction Choices answer, so the draft-blocklist question was removed.
        .acquisitionSource,
        .method,
        .schedule,
        .reminderTime,
        .reminderPlan,
        // .mechanismProof intentionally omitted: the diagnosis reveal now leads
        // straight into the Trial Granted Moment. The step + view are retained but
        // unreachable.
        // .paywall and .freePlanConfirmation retired (issue #164 / ADR 0007): the
        // Reverse Trial replaces the onboarding purchase offer, so the Trial Granted
        // Moment sits at the old paywall position and everyone proceeds into the
        // Screen Time branch.
        .trialGranted,
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

    static func visibleStep(for rawValue: Int, isPlus: Bool, selectedFreePlan: Bool) -> Step? {
        guard let step = step(for: rawValue) else { return nil }

        // The review request was retired. Anyone persisted on the old step (or handed
        // off to it) is migrated forward to the first question so they never land on
        // the removed screen.
        if step == .reviewPrompt {
            return .painPoints
        }

        // The "which apps to block" draft question was removed; anyone persisted on
        // it (or handed off to it) is migrated forward to the next question.
        if step == .draftBlockedApps {
            return .acquisitionSource
        }

        // The paywall (and the free-plan confirmation behind it) was retired by the
        // Reverse Trial (issue #164 / ADR 0007). Anyone persisted mid-onboarding on
        // either step resumes at the Trial Granted Moment, and the free-plan divert
        // away from `appBlocking` is gone — blocker setup runs under real Plus
        // Access for everyone.
        if step == .paywall || step == .freePlanConfirmation {
            return .trialGranted
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

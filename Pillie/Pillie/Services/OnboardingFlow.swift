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
        case draftBlockedApps = 18
        // Mechanism Proof added by issue #78. Appended for the same reason; it sits
        // between the diagnosis reveal (`reminderPlan` slot) and the paywall.
        case mechanismProof = 19

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
    static let paywallStep: Step = .paywall
    static let finalOnboardingStep: Step = .appBlocking
    static let completedStep: Step = .complete
    static let displayOrder: [Step] = [
        .welcome,
        .productDemo,
        .plusBlockingDemo,
        .analyticsConsent,
        .reviewPrompt,
        .painPoints,
        .goal,
        .missFrequency,
        .riskWindow,
        .draftBlockedApps,
        .acquisitionSource,
        .method,
        .schedule,
        .reminderTime,
        .reminderPlan,
        // .mechanismProof intentionally omitted: the diagnosis reveal now leads
        // straight into the paywall. The step + view are retained but unreachable.
        .paywall,
        .freePlanConfirmation,
        .appBlocking,
        .complete,
    ]

    static func step(for rawValue: Int) -> Step? {
        Step(rawValue: rawValue)
    }

    static func analyticsStep(for rawValue: Int) -> AnalyticsStep? {
        step(for: rawValue)?.analyticsStep
    }

    static func nextStepAfterPaywall(isPlus: Bool, selectedFreePlan: Bool) -> Step {
        if selectedFreePlan || !isPlus {
            return .freePlanConfirmation
        }

        return .appBlocking
    }

    static func visibleStep(for rawValue: Int, isPlus: Bool, selectedFreePlan: Bool) -> Step? {
        guard let step = step(for: rawValue) else { return nil }

        if step == .appBlocking, selectedFreePlan || !isPlus {
            return .freePlanConfirmation
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

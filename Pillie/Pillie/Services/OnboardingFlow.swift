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

    struct ShellState: Equatable {
        let showsBackButton: Bool
        let progressFraction: Double
        let progressLabel: String
        let primaryActionTitle: String
        let secondaryActionTitle: String?
        let isPrimaryActionEnabled: Bool
    }

    static let firstStep: Step = .welcome
    static let paywallStep: Step = .paywall
    static let finalOnboardingStep: Step = .appBlocking
    static let completedStep: Step = .complete
    static let displayOrder: [Step] = [
        .welcome,
        .analyticsConsent,
        .productDemo,
        .reviewPrompt,
        .painPoints,
        .goal,
        .missFrequency,
        .acquisitionSource,
        .method,
        .schedule,
        .reminderTime,
        .reminderPlan,
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

    static func nextStep(after step: Step) -> Step? {
        guard let index = displayOrder.firstIndex(of: step),
              displayOrder.indices.contains(index + 1) else {
            return nil
        }

        return displayOrder[index + 1]
    }

    static func shellState(for step: Step) -> ShellState? {
        switch step {
        case .analyticsConsent:
            return ShellState(
                showsBackButton: true,
                progressFraction: 0.2,
                progressLabel: "STEP 2/10",
                primaryActionTitle: "Allow Analytics",
                secondaryActionTitle: "Not Now",
                isPrimaryActionEnabled: true
            )
        default:
            return nil
        }
    }

    static func visibleStep(for rawValue: Int, isPlus: Bool, selectedFreePlan: Bool) -> Step? {
        guard let step = step(for: rawValue) else { return nil }

        if step == .plusBlockingDemo {
            return .productDemo
        }

        if step == .appBlocking, selectedFreePlan || !isPlus {
            return .freePlanConfirmation
        }

        return step
    }

    static func isOnboardingActive(rawStep: Int) -> Bool {
        rawStep < completedStep.rawValue
    }

    static func completedOnboarding(from previousRawStep: Int, to nextRawStep: Int) -> Bool {
        previousRawStep <= finalOnboardingStep.rawValue && nextRawStep >= completedStep.rawValue
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

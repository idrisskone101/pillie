import XCTest

@testable import Pillie

final class OnboardingFlowTests: XCTestCase {
    func testRawStepOrderPreservesPersistedOnboardingState() {
        XCTAssertEqual(OnboardingFlow.Step.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingFlow.Step.analyticsConsent.rawValue, 1)
        XCTAssertEqual(OnboardingFlow.Step.productDemo.rawValue, 2)
        XCTAssertEqual(OnboardingFlow.Step.plusBlockingDemo.rawValue, 3)
        XCTAssertEqual(OnboardingFlow.Step.reviewPrompt.rawValue, 4)
        XCTAssertEqual(OnboardingFlow.Step.painPoints.rawValue, 5)
        XCTAssertEqual(OnboardingFlow.Step.goal.rawValue, 6)
        XCTAssertEqual(OnboardingFlow.Step.missFrequency.rawValue, 7)
        XCTAssertEqual(OnboardingFlow.Step.acquisitionSource.rawValue, 8)
        XCTAssertEqual(OnboardingFlow.Step.method.rawValue, 9)
        XCTAssertEqual(OnboardingFlow.Step.schedule.rawValue, 10)
        XCTAssertEqual(OnboardingFlow.Step.reminderTime.rawValue, 11)
        XCTAssertEqual(OnboardingFlow.Step.reminderPlan.rawValue, 12)
        XCTAssertEqual(OnboardingFlow.Step.paywall.rawValue, 13)
        XCTAssertEqual(OnboardingFlow.Step.freePlanConfirmation.rawValue, 14)
        XCTAssertEqual(OnboardingFlow.Step.appBlocking.rawValue, 15)
        XCTAssertEqual(OnboardingFlow.Step.complete.rawValue, 16)
    }

    func testDisplayOrderStartsWithWelcomeThenAnalyticsConsentBeforeAnyLaterSetup() {
        XCTAssertEqual(
            Array(OnboardingFlow.displayOrder.prefix(5)),
            [.welcome, .analyticsConsent, .productDemo, .reviewPrompt, .painPoints]
        )
    }

    func testPlusUsersRouteFromPaywallToAppBlockingSetup() {
        XCTAssertEqual(
            OnboardingFlow.nextStepAfterPaywall(isPlus: true, selectedFreePlan: false),
            .appBlocking
        )
    }

    func testFreeUsersRouteFromPaywallToFreePlanConfirmation() {
        XCTAssertEqual(
            OnboardingFlow.nextStepAfterPaywall(isPlus: false, selectedFreePlan: true),
            .freePlanConfirmation
        )
        XCTAssertEqual(
            OnboardingFlow.nextStepAfterPaywall(isPlus: false, selectedFreePlan: false),
            .freePlanConfirmation
        )
    }

    func testFirstSliceRoutesWelcomeThroughAnalyticsConsentBeforeProof() {
        XCTAssertEqual(OnboardingFlow.nextStep(after: .welcome), .analyticsConsent)
        XCTAssertEqual(OnboardingFlow.nextStep(after: .analyticsConsent), .productDemo)
    }

    func testVisibleStepHidesAppBlockingFromFreeUsers() {
        XCTAssertEqual(
            OnboardingFlow.visibleStep(
                for: OnboardingFlow.Step.appBlocking.rawValue,
                isPlus: false,
                selectedFreePlan: false
            ),
            .freePlanConfirmation
        )
        XCTAssertEqual(
            OnboardingFlow.visibleStep(
                for: OnboardingFlow.Step.appBlocking.rawValue,
                isPlus: true,
                selectedFreePlan: true
            ),
            .freePlanConfirmation
        )
        XCTAssertEqual(
            OnboardingFlow.visibleStep(
                for: OnboardingFlow.Step.appBlocking.rawValue,
                isPlus: true,
                selectedFreePlan: false
            ),
            .appBlocking
        )
    }

    func testVisibleStepNormalizesLegacyPlusBlockingDemoToCurrentProofStep() {
        XCTAssertEqual(
            OnboardingFlow.visibleStep(
                for: OnboardingFlow.Step.plusBlockingDemo.rawValue,
                isPlus: false,
                selectedFreePlan: false
            ),
            .productDemo
        )
    }

    func testAnalyticsConsentShellHasProgressBackNavigationAndFixedActions() throws {
        let shell = try XCTUnwrap(OnboardingFlow.shellState(for: .analyticsConsent))

        XCTAssertTrue(shell.showsBackButton)
        XCTAssertEqual(shell.progressFraction, 0.2, accuracy: 0.001)
        XCTAssertEqual(shell.progressLabel, "STEP 2/10")
        XCTAssertEqual(shell.primaryActionTitle, "Allow Analytics")
        XCTAssertEqual(shell.secondaryActionTitle, "Not Now")
        XCTAssertTrue(shell.isPrimaryActionEnabled)
    }

    func testStepAnalyticsMappingPlacesRealSetupBeforePaywall() {
        XCTAssertEqual(OnboardingFlow.Step.welcome.analyticsStep, .welcome)
        XCTAssertEqual(OnboardingFlow.Step.analyticsConsent.analyticsStep, .analyticsConsent)
        XCTAssertEqual(OnboardingFlow.Step.productDemo.analyticsStep, .productDemo)
        XCTAssertEqual(OnboardingFlow.Step.plusBlockingDemo.analyticsStep, .plusBlockingDemo)
        XCTAssertEqual(OnboardingFlow.Step.reviewPrompt.analyticsStep, .reviewPrompt)
        XCTAssertEqual(OnboardingFlow.Step.painPoints.analyticsStep, .painPoints)
        XCTAssertEqual(OnboardingFlow.Step.goal.analyticsStep, .goal)
        XCTAssertEqual(OnboardingFlow.Step.missFrequency.analyticsStep, .missFrequency)
        XCTAssertEqual(OnboardingFlow.Step.acquisitionSource.analyticsStep, .acquisitionSource)
        XCTAssertEqual(OnboardingFlow.Step.method.analyticsStep, .method)
        XCTAssertEqual(OnboardingFlow.Step.schedule.analyticsStep, .schedule)
        XCTAssertEqual(OnboardingFlow.Step.reminderTime.analyticsStep, .reminderTime)
        XCTAssertEqual(OnboardingFlow.Step.reminderPlan.analyticsStep, .reminderPlan)
        XCTAssertEqual(OnboardingFlow.Step.paywall.analyticsStep, .paywall)
        XCTAssertEqual(OnboardingFlow.Step.freePlanConfirmation.analyticsStep, .freePlanConfirmation)
        XCTAssertEqual(OnboardingFlow.Step.appBlocking.analyticsStep, .appBlocking)
        XCTAssertNil(OnboardingFlow.Step.complete.analyticsStep)
    }

    func testOnboardingActiveIncludesAppBlockingAndEndsAtCompleteStep() {
        XCTAssertTrue(OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.welcome.rawValue))
        XCTAssertTrue(OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.appBlocking.rawValue))
        XCTAssertFalse(OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.complete.rawValue))
    }

    func testCompletionBoundaryFiresWhenLeavingFinalOnboardingStepRange() {
        XCTAssertFalse(
            OnboardingFlow.completedOnboarding(
                from: OnboardingFlow.Step.reminderPlan.rawValue,
                to: OnboardingFlow.Step.paywall.rawValue
            )
        )
        XCTAssertTrue(
            OnboardingFlow.completedOnboarding(
                from: OnboardingFlow.Step.freePlanConfirmation.rawValue,
                to: OnboardingFlow.Step.complete.rawValue
            )
        )
        XCTAssertTrue(
            OnboardingFlow.completedOnboarding(
                from: OnboardingFlow.Step.appBlocking.rawValue,
                to: OnboardingFlow.Step.complete.rawValue
            )
        )
    }

    func testTransitionDescribesDirectionAnalyticsStepAndCompletion() throws {
        let forward = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.reminderPlan.rawValue,
                to: OnboardingFlow.Step.paywall.rawValue
            )
        )
        XCTAssertEqual(forward.from, .reminderPlan)
        XCTAssertEqual(forward.to, .paywall)
        XCTAssertEqual(forward.direction, .forward)
        XCTAssertEqual(forward.completedAnalyticsStep, .reminderPlan)
        XCTAssertFalse(forward.completesOnboarding)

        let back = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.paywall.rawValue,
                to: OnboardingFlow.Step.reminderPlan.rawValue
            )
        )
        XCTAssertEqual(back.direction, .backward)
        XCTAssertEqual(back.completedAnalyticsStep, .paywall)

        let complete = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.appBlocking.rawValue,
                to: OnboardingFlow.Step.complete.rawValue
            )
        )
        XCTAssertTrue(complete.completesOnboarding)
    }

    func testAnalyticsConsentFirstSliceCountsAsForwardNavigation() throws {
        let toAnalyticsConsent = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.welcome.rawValue,
                to: OnboardingFlow.Step.analyticsConsent.rawValue
            )
        )
        XCTAssertEqual(toAnalyticsConsent.direction, .forward)
        XCTAssertEqual(toAnalyticsConsent.completedAnalyticsStep, .welcome)

        let toProductDemo = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.analyticsConsent.rawValue,
                to: OnboardingFlow.Step.productDemo.rawValue
            )
        )
        XCTAssertEqual(toProductDemo.direction, .forward)
        XCTAssertEqual(toProductDemo.completedAnalyticsStep, .analyticsConsent)
    }
}

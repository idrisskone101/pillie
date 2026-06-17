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

    func testDisplayOrderPlacesAnalyticsConsentImmediatelyBeforeReviewPrompt() {
        XCTAssertEqual(
            Array(OnboardingFlow.displayOrder.prefix(5)),
            [.welcome, .productDemo, .plusBlockingDemo, .analyticsConsent, .reviewPrompt]
        )
    }

    // MARK: - Calibration steps inserted by issue #76 (Risk Window + Draft Apps)

    func testRiskWindowAndDraftBlockedAppsAreAppendedSoExistingRawValuesAreStable() {
        // The two calibration steps are appended (not renumbered) so persisted
        // onboardingStep values for the original flow are never reinterpreted.
        XCTAssertEqual(OnboardingFlow.Step.riskWindow.rawValue, 17)
        XCTAssertEqual(OnboardingFlow.Step.draftBlockedApps.rawValue, 18)
        XCTAssertGreaterThan(OnboardingFlow.Step.riskWindow.rawValue, OnboardingFlow.Step.complete.rawValue)
    }

    func testDisplayOrderRunsFailureRiskDraftAcquisitionInCalibrationOrder() {
        let order = OnboardingFlow.displayOrder
        let calibration: [OnboardingFlow.Step] = [.missFrequency, .riskWindow, .draftBlockedApps, .acquisitionSource]
        let indices = calibration.compactMap { order.firstIndex(of: $0) }
        XCTAssertEqual(indices.count, calibration.count, "Every calibration step must appear in displayOrder.")
        XCTAssertEqual(indices, indices.sorted(), "Calibration steps must be contiguous and ordered.")
        XCTAssertEqual(indices, Array(indices.first!...indices.last!), "Calibration steps must be contiguous.")
    }

    func testCalibrationStepsMapToSafeLowCardinalityAnalyticsLabels() {
        XCTAssertEqual(OnboardingFlow.Step.riskWindow.analyticsStep, .riskWindow)
        XCTAssertEqual(OnboardingFlow.Step.draftBlockedApps.analyticsStep, .draftBlockedApps)
        XCTAssertEqual(AnalyticsStep.riskWindow.rawValue, "risk_window")
        XCTAssertEqual(AnalyticsStep.draftBlockedApps.rawValue, "draft_blocked_apps")
    }

    func testInsertedCalibrationStepsCountAsActiveOnboarding() {
        // Appended raw values exceed `complete`, so onboarding-active must be
        // identity-based, not a raw-value magnitude comparison.
        XCTAssertTrue(OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.riskWindow.rawValue))
        XCTAssertTrue(OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.draftBlockedApps.rawValue))
    }

    func testAdvancingIntoCalibrationStepsDoesNotCompleteOnboarding() {
        // Without identity-based completion, missFrequency(7) -> riskWindow(17) would
        // look like "left the onboarding range and reached >= complete".
        XCTAssertFalse(
            OnboardingFlow.completedOnboarding(
                from: OnboardingFlow.Step.missFrequency.rawValue,
                to: OnboardingFlow.Step.riskWindow.rawValue
            )
        )
        XCTAssertFalse(
            OnboardingFlow.completedOnboarding(
                from: OnboardingFlow.Step.draftBlockedApps.rawValue,
                to: OnboardingFlow.Step.acquisitionSource.rawValue
            )
        )
    }

    func testCalibrationChainTransitionsResolveForwardAndBackByDisplayOrder() throws {
        let forwardPairs: [(OnboardingFlow.Step, OnboardingFlow.Step)] = [
            (.missFrequency, .riskWindow),
            (.riskWindow, .draftBlockedApps),
            (.draftBlockedApps, .acquisitionSource),
        ]
        for (from, to) in forwardPairs {
            let transition = try XCTUnwrap(OnboardingFlow.transition(from: from.rawValue, to: to.rawValue))
            XCTAssertEqual(transition.direction, .forward, "\(from) -> \(to) should be forward.")
            XCTAssertFalse(transition.completesOnboarding)
        }

        let back = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.acquisitionSource.rawValue,
                to: OnboardingFlow.Step.draftBlockedApps.rawValue
            )
        )
        XCTAssertEqual(back.direction, .backward)
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

    func testMovedAnalyticsConsentStillCountsAsForwardNavigation() throws {
        let toAnalyticsConsent = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.plusBlockingDemo.rawValue,
                to: OnboardingFlow.Step.analyticsConsent.rawValue
            )
        )
        XCTAssertEqual(toAnalyticsConsent.direction, .forward)
        XCTAssertEqual(toAnalyticsConsent.completedAnalyticsStep, .plusBlockingDemo)

        let toReviewPrompt = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.analyticsConsent.rawValue,
                to: OnboardingFlow.Step.reviewPrompt.rawValue
            )
        )
        XCTAssertEqual(toReviewPrompt.direction, .forward)
        XCTAssertEqual(toReviewPrompt.completedAnalyticsStep, .analyticsConsent)
    }
}

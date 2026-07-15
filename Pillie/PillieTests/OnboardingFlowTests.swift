import XCTest

@testable import Pillie

final class OnboardingFlowTests: XCTestCase {
    func testOnboardingProgressUsesOneThreeSectionDenominatorAcrossTheFlow() {
        let progress = [
            ProtectionPlanProgressIndex.progress(for: .productDemo),
            ProtectionPlanProgressIndex.progress(for: .painPoints),
            ProtectionPlanProgressIndex.progress(for: .method),
            ProtectionPlanProgressIndex.progress(for: .appBlocking),
        ]

        XCTAssertEqual(progress.map(\.total), [3, 3, 3, 3])
    }

    func testVisibleFlowAdvancesThroughSectionsWithoutMovingBackward() {
        let visibleSteps: [OnboardingFlow.Step] = [
            .productDemo,
            .plusBlockingDemo,
            .analyticsConsent,
            .painPoints,
            .goal,
            .missFrequency,
            .riskWindow,
            .acquisitionSource,
            .method,
            .schedule,
            .reminderTime,
            .reminderPlan,
            .appBlocking,
            .protectionPlanReady,
        ]

        XCTAssertEqual(
            visibleSteps.map { ProtectionPlanProgressIndex.progress(for: $0).index },
            [1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3]
        )
    }

    func testSectionProgressProvidesMeaningfulVoiceOverAnnouncements() {
        XCTAssertEqual(
            String(localized: ProtectionPlanProgressIndex.progress(for: .productDemo).accessibilityLabel),
            "See how Pillie works, section 1 of 3"
        )
        XCTAssertEqual(
            String(localized: ProtectionPlanProgressIndex.progress(for: .painPoints).accessibilityLabel),
            "Personalize your plan, section 2 of 3"
        )
        XCTAssertEqual(
            String(localized: ProtectionPlanProgressIndex.progress(for: .reminderTime).accessibilityLabel),
            "Set your reminder, section 3 of 3"
        )
    }

    func testRetiredConditionalStepsResolveWithoutChangingSections() throws {
        let migrations: [(OnboardingFlow.Step, OnboardingFlow.Step)] = [
            (.reviewPrompt, .painPoints),
            (.draftBlockedApps, .acquisitionSource),
            (.paywall, .appBlocking),
            (.freePlanConfirmation, .appBlocking),
            (.trialGranted, .appBlocking),
        ]

        for (retired, expectedVisible) in migrations {
            let visible = try XCTUnwrap(
                OnboardingFlow.visibleStep(
                    for: retired.rawValue,
                    isPlus: false,
                    selectedFreePlan: false
                )
            )
            XCTAssertEqual(visible, expectedVisible)
            XCTAssertEqual(
                ProtectionPlanProgressIndex.progress(for: retired).section,
                ProtectionPlanProgressIndex.progress(for: visible).section,
                "Migrating \(retired) must not change user-facing progress."
            )
        }
    }

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

    func testDisplayOrderPlacesAnalyticsConsentImmediatelyBeforeFirstQuestion() {
        // The review request was retired, so Analytics Consent now hands straight
        // off to the first question (Distraction Choices / painPoints).
        XCTAssertEqual(
            Array(OnboardingFlow.displayOrder.prefix(5)),
            [.welcome, .productDemo, .plusBlockingDemo, .analyticsConsent, .painPoints]
        )
        XCTAssertFalse(OnboardingFlow.displayOrder.contains(.reviewPrompt))
    }

    func testRetiredReviewPromptStepMigratesForwardToFirstQuestion() {
        // The raw value is preserved for persistence, but anyone landing on it is
        // migrated to the first question instead of the removed review screen.
        XCTAssertEqual(OnboardingFlow.Step.reviewPrompt.rawValue, 4)
        XCTAssertEqual(
            OnboardingFlow.visibleStep(
                for: OnboardingFlow.Step.reviewPrompt.rawValue,
                isPlus: false,
                selectedFreePlan: false
            ),
            .painPoints
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

    func testDisplayOrderRunsFailureRiskAcquisitionInCalibrationOrder() {
        let order = OnboardingFlow.displayOrder
        // Draft Blocked Apps was retired, so the calibration run is Failure → Risk
        // Window → Acquisition Source (no draft-blocklist step between them).
        let calibration: [OnboardingFlow.Step] = [.missFrequency, .riskWindow, .acquisitionSource]
        let indices = calibration.compactMap { order.firstIndex(of: $0) }
        XCTAssertEqual(indices.count, calibration.count, "Every calibration step must appear in displayOrder.")
        XCTAssertEqual(indices, indices.sorted(), "Calibration steps must be contiguous and ordered.")
        XCTAssertEqual(indices, Array(indices.first!...indices.last!), "Calibration steps must be contiguous.")
        XCTAssertFalse(order.contains(.draftBlockedApps), "Retired draft-blocklist step must not be in displayOrder.")
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
            (.riskWindow, .acquisitionSource),
        ]
        for (from, to) in forwardPairs {
            let transition = try XCTUnwrap(OnboardingFlow.transition(from: from.rawValue, to: to.rawValue))
            XCTAssertEqual(transition.direction, .forward, "\(from) -> \(to) should be forward.")
            XCTAssertFalse(transition.completesOnboarding)
        }

        let back = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.acquisitionSource.rawValue,
                to: OnboardingFlow.Step.riskWindow.rawValue
            )
        )
        XCTAssertEqual(back.direction, .backward)
    }

    func testDraftBlockedAppsIsRetiredAndMigratesForwardToAcquisitionSource() {
        // The draft-blocklist question was removed. Its case + raw value are retained
        // for persistence compatibility, but it is dropped from displayOrder and anyone
        // persisted on it is migrated forward so they never land on the removed screen.
        XCTAssertEqual(OnboardingFlow.Step.draftBlockedApps.rawValue, 18)
        XCTAssertFalse(OnboardingFlow.displayOrder.contains(.draftBlockedApps))
        XCTAssertEqual(
            OnboardingFlow.visibleStep(
                for: OnboardingFlow.Step.draftBlockedApps.rawValue,
                isPlus: false,
                selectedFreePlan: false
            ),
            .acquisitionSource
        )
    }

    // MARK: - Mechanism Proof step inserted by issue #78

    func testMechanismProofIsAppendedSoExistingRawValuesAreStable() {
        // Appended (not renumbered), like #76's calibration steps, so persisted
        // onboardingStep values for the original flow are never reinterpreted.
        XCTAssertEqual(OnboardingFlow.Step.mechanismProof.rawValue, 19)
        XCTAssertGreaterThan(
            OnboardingFlow.Step.mechanismProof.rawValue,
            OnboardingFlow.Step.complete.rawValue
        )
    }

    func testMechanismProofMapsToSafeLowCardinalityAnalyticsLabel() {
        XCTAssertEqual(OnboardingFlow.Step.mechanismProof.analyticsStep, .mechanismProof)
        XCTAssertEqual(AnalyticsStep.mechanismProof.rawValue, "mechanism_proof")
    }

    func testMechanismProofIsOmittedFromDisplayOrder() {
        // The Mechanism Proof demo was dropped from the flow: the diagnosis reveal now
        // leads straight into the paywall. The step + view are retained but unreachable.
        XCTAssertFalse(OnboardingFlow.displayOrder.contains(.mechanismProof))
    }

    // MARK: - Trial Granted Moment replaces the paywall (issue #164 / ADR 0007)

    func testTrialGrantedIsAppendedSoExistingRawValuesAreStable() {
        // Appended (not renumbered) so persisted `onboardingStep` values are never
        // reinterpreted; its flow position is expressed by `displayOrder`.
        XCTAssertEqual(OnboardingFlow.Step.trialGranted.rawValue, 21)
        XCTAssertEqual(OnboardingFlow.Step.paywall.rawValue, 13)
        XCTAssertEqual(OnboardingFlow.Step.freePlanConfirmation.rawValue, 14)
    }

    func testDisplayOrderRoutesDiagnosisDirectlyIntoAppBlocking() {
        XCTAssertEqual(OnboardingFlow.nextStep(after: .reminderPlan), .appBlocking)
        XCTAssertFalse(
            OnboardingFlow.displayOrder.contains(.trialGranted),
            "The Trial Granted Moment is no longer a blocking onboarding step."
        )
    }

    func testAppBlockingBackNavigationReturnsDirectlyToDiagnosis() {
        XCTAssertEqual(OnboardingFlow.previousStep(before: .appBlocking), .reminderPlan)
    }

    func testReverseTrialIsGrantedWhenAppBlockingBecomesVisible() {
        XCTAssertTrue(OnboardingFlow.grantsReverseTrial(on: .appBlocking))
        XCTAssertFalse(OnboardingFlow.grantsReverseTrial(on: .trialGranted))
    }

    func testTrialGrantedMapsToSafeLowCardinalityAnalyticsLabel() {
        XCTAssertEqual(OnboardingFlow.Step.trialGranted.analyticsStep, .trialGranted)
        XCTAssertEqual(AnalyticsStep.trialGranted.rawValue, "trial_granted_moment")
    }

    func testPaywallAndFreePlanConfirmationAreRetiredFromDisplayOrder() {
        // No purchase UI exists anywhere in onboarding: both the paywall step and
        // the free-plan-confirmation branch behind it are gone from the flow.
        XCTAssertFalse(OnboardingFlow.displayOrder.contains(.paywall))
        XCTAssertFalse(OnboardingFlow.displayOrder.contains(.freePlanConfirmation))
    }

    func testDiagnosisToAppBlockingResolvesForwardWithoutCompletingOnboarding() throws {
        let toAppBlocking = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.reminderPlan.rawValue,
                to: OnboardingFlow.Step.appBlocking.rawValue
            )
        )
        XCTAssertEqual(toAppBlocking.direction, .forward)
        XCTAssertFalse(toAppBlocking.completesOnboarding)
    }

    func testTrialGrantedCountsAsActiveOnboardingSoAbandonersResumeWithTheirTrial() {
        // The retired raw value remains an active onboarding identity so it migrates
        // forward to app-blocking setup, never to completed app state.
        XCTAssertTrue(OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.trialGranted.rawValue))
    }

    func testRetiredTrialAndPaywallStepsMigrateForwardToAppBlocking() {
        // Anyone persisted on a retired announcement or purchase step resumes at
        // app-blocking setup instead of seeing the removed gate.
        for retired in [OnboardingFlow.Step.paywall, .freePlanConfirmation, .trialGranted] {
            for isPlus in [true, false] {
                for selectedFreePlan in [true, false] {
                    XCTAssertEqual(
                        OnboardingFlow.visibleStep(
                            for: retired.rawValue,
                            isPlus: isPlus,
                            selectedFreePlan: selectedFreePlan
                        ),
                        .appBlocking,
                        "\(retired) should migrate to app-blocking setup."
                    )
                }
            }
        }
    }

    func testEveryUserFlowsIntoScreenTimeBranchRegardlessOfPlanState() {
        // The free-plan divert is gone: blocker setup runs under real Plus Access
        // (the Reverse Trial), so appBlocking renders for everyone.
        for isPlus in [true, false] {
            for selectedFreePlan in [true, false] {
                XCTAssertEqual(
                    OnboardingFlow.visibleStep(
                        for: OnboardingFlow.Step.appBlocking.rawValue,
                        isPlus: isPlus,
                        selectedFreePlan: selectedFreePlan
                    ),
                    .appBlocking
                )
            }
        }
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

    // MARK: - Pill Protection Plan Ready step inserted by issue #83

    func testProtectionPlanReadyIsAppendedSoExistingRawValuesAreStable() {
        // Appended (not renumbered), like #76/#78, so persisted onboardingStep values
        // for the original flow are never reinterpreted.
        XCTAssertEqual(OnboardingFlow.Step.protectionPlanReady.rawValue, 20)
        XCTAssertGreaterThan(
            OnboardingFlow.Step.protectionPlanReady.rawValue,
            OnboardingFlow.Step.complete.rawValue
        )
    }

    func testProtectionPlanReadyMapsToSafeLowCardinalityAnalyticsLabel() {
        XCTAssertEqual(OnboardingFlow.Step.protectionPlanReady.analyticsStep, .protectionPlanReady)
        XCTAssertEqual(AnalyticsStep.protectionPlanReady.rawValue, "protection_plan_ready")
    }

    func testProtectionPlanReadySitsBetweenAppBlockingAndCompleteInDisplayOrder() throws {
        // Activated users finish App Blocking, land on the ready screen, then open the
        // app — so the ready step renders directly between the two.
        let order = OnboardingFlow.displayOrder
        let appBlocking = try XCTUnwrap(order.firstIndex(of: .appBlocking))
        let ready = try XCTUnwrap(order.firstIndex(of: .protectionPlanReady))
        let complete = try XCTUnwrap(order.firstIndex(of: .complete))
        XCTAssertEqual(ready, appBlocking + 1, "Ready follows the app-blocking save directly.")
        XCTAssertEqual(complete, ready + 1, "The app opens right after the ready screen.")
    }

    func testReachingProtectionPlanReadyDoesNotCompleteOnboarding() {
        // Saving the blocker config advances to the ready screen, which is still active
        // onboarding. Completion (and activation classification) fires only when the
        // ready screen hands off into the app.
        XCTAssertTrue(
            OnboardingFlow.isOnboardingActive(rawStep: OnboardingFlow.Step.protectionPlanReady.rawValue)
        )
        XCTAssertFalse(
            OnboardingFlow.completedOnboarding(
                from: OnboardingFlow.Step.appBlocking.rawValue,
                to: OnboardingFlow.Step.protectionPlanReady.rawValue
            )
        )
    }

    func testAppBlockingToProtectionPlanReadyResolvesForwardWithoutCompleting() throws {
        let transition = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.appBlocking.rawValue,
                to: OnboardingFlow.Step.protectionPlanReady.rawValue
            )
        )
        XCTAssertEqual(transition.direction, .forward)
        XCTAssertFalse(transition.completesOnboarding)
    }

    func testProtectionPlanReadyToCompleteFinishesOnboardingAndKeepsCompletedStepLabel() throws {
        let transition = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.protectionPlanReady.rawValue,
                to: OnboardingFlow.Step.complete.rawValue
            )
        )
        XCTAssertEqual(transition.direction, .forward)
        XCTAssertTrue(transition.completesOnboarding)
        // A non-nil completed step keeps the generic step machine firing
        // `onboarding_completed` when the ready screen hands off into the app.
        XCTAssertEqual(transition.completedAnalyticsStep, .protectionPlanReady)
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

        let toFirstQuestion = try XCTUnwrap(
            OnboardingFlow.transition(
                from: OnboardingFlow.Step.analyticsConsent.rawValue,
                to: OnboardingFlow.Step.painPoints.rawValue
            )
        )
        XCTAssertEqual(toFirstQuestion.direction, .forward)
        XCTAssertEqual(toFirstQuestion.completedAnalyticsStep, .analyticsConsent)
    }

    func testDisplayIndexReportsZeroBasedPositionWithinDisplayOrder() {
        // step_index for the funnel is the step's position in `displayOrder` — the
        // canonical render/funnel sequence — not its frozen raw value. So it is
        // monotonic with real progression even though raw values have gaps.
        XCTAssertEqual(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.welcome.rawValue), 0)
        XCTAssertEqual(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.painPoints.rawValue), 4)
        // The retired Trial Granted Moment is no longer a funnel position (#204),
        // so the Screen Time branch follows the diagnosis directly.
        XCTAssertNil(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.trialGranted.rawValue))
        XCTAssertEqual(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.appBlocking.rawValue), 13)

        // Every visible step's index matches its position in displayOrder exactly.
        for (position, step) in OnboardingFlow.displayOrder.enumerated() {
            XCTAssertEqual(
                OnboardingFlow.displayIndex(for: step.rawValue), position,
                "\(step) should report its displayOrder position as step_index.")
        }
    }

    func testDisplayIndexIsNilForRetiredAndUnknownSteps() {
        // Retired steps are dropped from displayOrder (their raw values are kept only
        // so persisted state is never reinterpreted), so they have no funnel position.
        XCTAssertNil(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.reviewPrompt.rawValue))
        XCTAssertNil(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.draftBlockedApps.rawValue))
        XCTAssertNil(OnboardingFlow.displayIndex(for: OnboardingFlow.Step.mechanismProof.rawValue))
        // An out-of-range raw value (no such step) has no position either.
        XCTAssertNil(OnboardingFlow.displayIndex(for: 999))
    }
}

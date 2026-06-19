//
//  ProtectionPlanOnboardingTests.swift
//  PillieTests
//
//  Covers the deep, UI-free state core of Protection Plan Onboarding: step
//  routing, forward/back navigation with committed-answer preservation, and
//  persistence across app interruption. Exercises value types directly so there
//  is no main-actor `@Observable` deinit hazard in the test host.
//

import XCTest

@testable import Pillie

final class ProtectionPlanOnboardingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProtectionPlanOnboardingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Step routing

    func testWelcomeIsFirstStepAndAnalyticsConsentFollowsImmediately() {
        XCTAssertEqual(ProtectionPlanStep.first, .welcome)
        XCTAssertEqual(ProtectionPlanStep.welcome.next, .analyticsConsent)
    }

    func testNewStateStartsAtWelcomeWithNoBackNavigation() {
        let state = ProtectionPlanOnboardingState()
        XCTAssertEqual(state.currentStep, .welcome)
        XCTAssertFalse(state.canGoBack)
    }

    // MARK: - Forward / back navigation

    func testAdvanceMovesToTheNextStepInOrder() {
        var state = ProtectionPlanOnboardingState()
        state.advance()
        XCTAssertEqual(state.currentStep, .analyticsConsent)
        XCTAssertTrue(state.canGoBack)
    }

    func testGoBackReturnsToThePreviousStep() {
        var state = ProtectionPlanOnboardingState()
        state.advance()
        state.goBack()
        XCTAssertEqual(state.currentStep, .welcome)
    }

    func testGoBackPreservesCommittedConsentAnswer() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> analyticsConsent
        state.recordAnalyticsConsent(allowed: true)
        state.advance() // commit consent, move past the intro

        state.goBack() // back to analyticsConsent
        XCTAssertEqual(state.currentStep, .analyticsConsent)
        XCTAssertEqual(state.analyticsConsentDecision, .allowed)
    }

    // MARK: - Early Value Proof routing (#74)

    func testEarlyValueProofAppearsAfterConsentAndBeforeHandoff() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> analyticsConsent
        state.recordAnalyticsConsent(allowed: true)
        state.advance() // commit consent -> earlyValueProof

        XCTAssertEqual(state.currentStep, .earlyValueProof)
        XCTAssertFalse(
            state.hasFinishedIntro,
            "The Early Value Proof is still rendered by the new shell, so the flow must not hand off to the legacy questions yet."
        )
    }

    func testIntroHandsOffOnceTheProofAdvancesToTheReviewPrompt() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> analyticsConsent
        XCTAssertFalse(state.hasFinishedIntro)
        state.advance() // -> earlyValueProof
        XCTAssertFalse(state.hasFinishedIntro)
        state.advance() // -> reviewPrompt (handoff sentinel into the questions flow)

        XCTAssertEqual(state.currentStep, .reviewPrompt)
        XCTAssertTrue(
            state.hasFinishedIntro,
            "Reaching the handoff sentinel hands off to the questions flow."
        )
    }

    func testGoBackFromHandoffSentinelReturnsToTheProofAndReentersTheShell() {
        // Backing out of the first question reverses the intro handoff. Stepping back
        // from the sentinel must land on the Early Value Proof and report the intro
        // as unfinished, so the shell re-renders the proof instead of immediately
        // re-triggering the handoff (which would bounce the user forward).
        var state = ProtectionPlanOnboardingState(currentStep: .reviewPrompt)
        XCTAssertTrue(state.hasFinishedIntro)

        state.goBack()
        XCTAssertEqual(state.currentStep, .earlyValueProof)
        XCTAssertFalse(
            state.hasFinishedIntro,
            "Returning to the proof must re-enter the new shell, not re-fire the handoff."
        )
    }

    func testGoBackFromProofReturnsToConsentPreservingTheAnswer() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> analyticsConsent
        state.recordAnalyticsConsent(allowed: false)
        state.advance() // -> earlyValueProof

        state.goBack() // back to analyticsConsent
        XCTAssertEqual(state.currentStep, .analyticsConsent)
        XCTAssertEqual(state.analyticsConsentDecision, .declined)
    }

    // MARK: - Persistence / interruption

    func testCommittedStateSurvivesAppInterruption() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> analyticsConsent
        state.recordAnalyticsConsent(allowed: false)
        ProtectionPlanOnboardingStore.save(state, to: defaults)

        // Simulate the app being killed and relaunched.
        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.currentStep, .analyticsConsent)
        XCTAssertEqual(resumed.analyticsConsentDecision, .declined)
    }

    func testFreshDefaultsLoadToWelcomeUndecided() {
        let loaded = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(loaded.currentStep, .welcome)
        XCTAssertEqual(loaded.analyticsConsentDecision, .undecided)
    }
}

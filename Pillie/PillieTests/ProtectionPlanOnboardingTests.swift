//
//  ProtectionPlanOnboardingTests.swift
//  PillieTests
//
//  Covers the deep, UI-free state core of Protection Plan Onboarding: step
//  routing, forward/back navigation, and persistence across app interruption.
//  Exercises value types directly so there is no main-actor `@Observable` deinit
//  hazard in the test host.
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

    func testWelcomeIsFirstStepAndProofFollowsImmediately() {
        // Analytics Consent was retired, so Welcome leads straight to the Early
        // Value Proof (analytics is collected for everyone, no consent screen).
        XCTAssertEqual(ProtectionPlanStep.first, .welcome)
        XCTAssertEqual(ProtectionPlanStep.welcome.next, .earlyValueProof)
    }

    func testNewStateStartsAtWelcomeWithNoBackNavigation() {
        let state = ProtectionPlanOnboardingState()
        XCTAssertEqual(state.currentStep, .welcome)
        XCTAssertFalse(state.canGoBack)
    }

    // MARK: - Forward / back navigation

    func testAdvanceMovesFromWelcomeToTheProof() {
        var state = ProtectionPlanOnboardingState()
        state.advance()
        XCTAssertEqual(state.currentStep, .earlyValueProof)
        XCTAssertTrue(state.canGoBack)
    }

    func testGoBackFromProofReturnsToWelcome() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> earlyValueProof
        state.goBack()
        XCTAssertEqual(state.currentStep, .welcome)
    }

    // MARK: - Early Value Proof routing (#74)

    func testEarlyValueProofAppearsAfterWelcomeAndBeforeHandoff() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // welcome -> earlyValueProof

        XCTAssertEqual(state.currentStep, .earlyValueProof)
        XCTAssertFalse(
            state.hasFinishedIntro,
            "The Early Value Proof is still rendered by the new shell, so the flow must not hand off to the legacy questions yet."
        )
    }

    func testIntroHandsOffOnceTheProofAdvancesToTheReviewPrompt() {
        var state = ProtectionPlanOnboardingState()
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

    // MARK: - Persistence / interruption

    func testCommittedStateSurvivesAppInterruption() {
        var state = ProtectionPlanOnboardingState()
        state.advance() // -> earlyValueProof
        ProtectionPlanOnboardingStore.save(state, to: defaults)

        // Simulate the app being killed and relaunched.
        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.currentStep, .earlyValueProof)
    }

    func testPersistedAnalyticsConsentStepMigratesForwardToProofOnLoad() {
        // Analytics Consent was retired; a user persisted on the old consent step
        // resumes on the Early Value Proof rather than the removed screen.
        let state = ProtectionPlanOnboardingState(currentStep: .analyticsConsent)
        ProtectionPlanOnboardingStore.save(state, to: defaults)

        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.currentStep, .earlyValueProof)
    }

    func testFreshDefaultsLoadToWelcome() {
        let loaded = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(loaded.currentStep, .welcome)
    }
}

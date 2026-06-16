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

    // MARK: - Intro handoff

    func testIntroIsNotFinishedUntilAnalyticsConsentIsCommitted() {
        var state = ProtectionPlanOnboardingState()
        XCTAssertFalse(state.hasFinishedIntro) // welcome
        state.advance()
        XCTAssertFalse(state.hasFinishedIntro) // analyticsConsent
        state.advance() // moves past analyticsConsent
        XCTAssertTrue(state.hasFinishedIntro)
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

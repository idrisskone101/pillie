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

    func testNewStateStartsAtWelcomeWithNoBackNavigation() {
        let state = ProtectionPlanOnboardingState()
        XCTAssertEqual(state.currentStep, .welcome)
        XCTAssertFalse(state.canGoBack)
        XCTAssertFalse(state.hasFinishedIntro)
    }

    func testAdvanceMovesFromWelcomeToTheHandoff() {
        var state = ProtectionPlanOnboardingState()
        state.advance()
        XCTAssertEqual(state.currentStep, .reviewPrompt)
        XCTAssertTrue(state.hasFinishedIntro)
    }

    func testGoBackFromTheHandoffReturnsToWelcomeAndReentersTheShell() {
        var state = ProtectionPlanOnboardingState(currentStep: .reviewPrompt)
        state.goBack()
        XCTAssertEqual(state.currentStep, .welcome)
        XCTAssertFalse(state.hasFinishedIntro)
    }

    // MARK: - Persistence / interruption

    func testCommittedStateSurvivesAppInterruption() {
        var state = ProtectionPlanOnboardingState()
        state.advance()
        state.recordDistractionChoices([.instagram])
        ProtectionPlanOnboardingStore.save(state, to: defaults)

        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.currentStep, .reviewPrompt)
        XCTAssertEqual(resumed.distractionChoices, [.instagram])
    }

    func testPersistedAnalyticsConsentStepLoadsOnTheHandoff() {
        defaults.set(1, forKey: ProtectionPlanOnboardingStore.Keys.step)

        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.currentStep, .reviewPrompt)
        XCTAssertTrue(resumed.hasFinishedIntro)
    }

    func testUserParkedOnTheRetiredDemoLoadsOnTheHandoffWithHerAnswers() {
        defaults.set(2, forKey: ProtectionPlanOnboardingStore.Keys.step)
        defaults.set(["instagram"], forKey: ProtectionPlanOnboardingStore.Keys.distractionChoices)

        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.currentStep, .reviewPrompt)
        XCTAssertTrue(resumed.hasFinishedIntro)
        XCTAssertEqual(resumed.distractionChoices, [.instagram])
    }

    func testRetiredDemoMigrationIsStableAcrossSaveAndLoad() {
        defaults.set(2, forKey: ProtectionPlanOnboardingStore.Keys.step)

        let migrated = ProtectionPlanOnboardingStore.load(from: defaults)
        ProtectionPlanOnboardingStore.save(migrated, to: defaults)

        XCTAssertEqual(defaults.integer(forKey: ProtectionPlanOnboardingStore.Keys.step), 3)
        XCTAssertEqual(ProtectionPlanOnboardingStore.load(from: defaults).currentStep, .reviewPrompt)
    }

    func testFreshDefaultsLoadToWelcome() {
        let loaded = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(loaded.currentStep, .welcome)
    }
}

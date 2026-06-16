//
//  ProtectionPlanQuestionAnswersTests.swift
//  PillieTests
//
//  Covers the first plan-question slice (#75): the new Distraction Choice and
//  Delay Consequence answer models plus the committed-answer behavior of the
//  Protection Plan Onboarding value core — selection semantics, persistence, and
//  back-navigation restore. Value types only, so there is no main-actor
//  `@Observable` deinit hazard in the test host.
//

import XCTest

@testable import Pillie

final class ProtectionPlanQuestionAnswersTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProtectionPlanQuestionAnswersTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - DistractionChoice (multi-select answer)

    func testDistractionChoiceExposesEveryDesignOptionIncludingOther() {
        // Matches the Superdesign "Distraction Choices" draft: concrete apps,
        // behaviours, then a trailing Other catch-all.
        let titles = DistractionChoice.allCases.map(\.title)
        XCTAssertEqual(
            titles,
            [
                "TikTok", "Instagram", "YouTube", "Messages",
                "I snooze it", "I'm busy", "I just forget", "Other"
            ]
        )
        XCTAssertTrue(DistractionChoice.allCases.contains(.other))
    }

    func testDistractionChoiceOtherIsTheTrailingCatchAll() {
        XCTAssertTrue(DistractionChoice.other.isOther)
        XCTAssertEqual(DistractionChoice.allCases.last, .other)
        XCTAssertEqual(DistractionChoice.allCases.filter(\.isOther), [.other])
    }

    func testDistractionChoiceRawValuesRoundTripForPersistence() {
        XCTAssertEqual(DistractionChoice.tiktok.rawValue, "tiktok")
        XCTAssertEqual(DistractionChoice.other.rawValue, "other")
        for choice in DistractionChoice.allCases {
            XCTAssertEqual(DistractionChoice(rawValue: choice.rawValue), choice)
        }
    }

    func testDistractionChoiceEveryOptionHasARowSymbol() {
        for choice in DistractionChoice.allCases {
            XCTAssertFalse(choice.symbolName.isEmpty, "\(choice) needs a row icon.")
        }
    }

    // MARK: - DelayConsequence (single-select answer)

    func testDelayConsequenceExposesEveryDesignOption() {
        // Matches the Superdesign "Delay Consequence" draft, in order.
        let titles = DelayConsequence.allCases.map(\.title)
        XCTAssertEqual(
            titles,
            ["Stressful", "Annoying", "Scary", "I overthink it", "I have to double-check", "I don't care much"]
        )
    }

    func testDelayConsequenceRawValuesRoundTripForPersistence() {
        XCTAssertEqual(DelayConsequence.stressful.rawValue, "stressful")
        for consequence in DelayConsequence.allCases {
            XCTAssertEqual(DelayConsequence(rawValue: consequence.rawValue), consequence)
        }
    }

    // MARK: - Committed answers on the state core

    func testNewStateHasNoCommittedDistractionOrDelayAnswers() {
        let state = ProtectionPlanOnboardingState()
        XCTAssertTrue(state.distractionChoices.isEmpty)
        XCTAssertNil(state.delayConsequence)
    }

    func testRecordingDistractionChoicesCommitsTheMultiSelectAnswer() {
        var state = ProtectionPlanOnboardingState()
        state.recordDistractionChoices([.tiktok, .forget, .other])
        XCTAssertEqual(state.distractionChoices, [.tiktok, .forget, .other])
    }

    func testRecordingDistractionChoicesReplacesThePreviousSelection() {
        var state = ProtectionPlanOnboardingState()
        state.recordDistractionChoices([.tiktok, .instagram])
        state.recordDistractionChoices([.messages])
        XCTAssertEqual(state.distractionChoices, [.messages])
    }

    func testRecordingDelayConsequenceCommitsTheSingleSelectAnswer() {
        var state = ProtectionPlanOnboardingState()
        state.recordDelayConsequence(.scary)
        XCTAssertEqual(state.delayConsequence, .scary)

        state.recordDelayConsequence(.annoying)
        XCTAssertEqual(state.delayConsequence, .annoying, "Delay Consequence is single-select; the latest answer wins.")
    }

    // MARK: - Persistence / interruption

    func testCommittedQuestionAnswersSurviveAppInterruption() {
        var state = ProtectionPlanOnboardingState()
        state.recordDistractionChoices([.youtube, .busy, .other])
        state.recordDelayConsequence(.overthink)
        ProtectionPlanOnboardingStore.save(state, to: defaults)

        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.distractionChoices, [.youtube, .busy, .other])
        XCTAssertEqual(resumed.delayConsequence, .overthink)
    }

    func testFreshDefaultsLoadWithNoCommittedQuestionAnswers() {
        let loaded = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertTrue(loaded.distractionChoices.isEmpty)
        XCTAssertNil(loaded.delayConsequence)
    }

    // MARK: - Back navigation restores committed answers

    func testCommittedAnswersAreRestoredWhenSteppingBackAndForward() {
        // Mirrors the user committing Distraction Choices, moving on, then going
        // back: the committed answers must still be there to re-seed the screen.
        var state = ProtectionPlanOnboardingState(currentStep: .distractionChoices)
        state.recordDistractionChoices([.instagram, .snooze])
        state.advance() // -> delayConsequence
        state.recordDelayConsequence(.doubleCheck)

        state.goBack() // back to distractionChoices
        XCTAssertEqual(state.currentStep, .distractionChoices)
        XCTAssertEqual(state.distractionChoices, [.instagram, .snooze])
        XCTAssertEqual(state.delayConsequence, .doubleCheck, "Stepping back must not erase a committed answer.")
    }
}

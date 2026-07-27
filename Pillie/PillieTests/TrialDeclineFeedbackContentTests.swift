//
//  TrialDeclineFeedbackContentTests.swift
//  PillieTests
//
//  Localized value-type UI contract for issue #243.
//

import XCTest

@testable import Pillie

final class TrialDeclineFeedbackContentTests: XCTestCase {
    func testQuestionnaireOffersExactlyTheSevenApprovedClosedReasons() {
        XCTAssertEqual(
            TrialDeclineFeedbackQuestionnaire.availableReasons.map(\.analyticsValue),
            [
                "too_expensive",
                "not_used_enough",
                "missing_feature",
                "just_trying",
                "prefer_another_app",
                "technical_issue",
                "other",
            ]
        )
    }

    func testQuestionnaireStartsBlankWithSubmitUnavailable() {
        let questionnaire = TrialDeclineFeedbackQuestionnaire()

        XCTAssertNil(questionnaire.selectedReason)
        XCTAssertFalse(questionnaire.canSubmit)
    }

    func testSelectingANewReasonReplacesThePreviousSelection() {
        var questionnaire = TrialDeclineFeedbackQuestionnaire()

        questionnaire.select(.tooExpensive)
        XCTAssertEqual(questionnaire.selectedReason, .tooExpensive)
        XCTAssertTrue(questionnaire.canSubmit)

        questionnaire.select(.technicalIssue)
        XCTAssertEqual(questionnaire.selectedReason, .technicalIssue)
    }

    func testEveryReasonCanSubmitATerminalClosedResponseWithoutARescueOffer() {
        for reason in TrialDeclineFeedbackQuestionnaire.availableReasons {
            var questionnaire = TrialDeclineFeedbackQuestionnaire()
            questionnaire.select(reason)

            XCTAssertEqual(
                questionnaire.submit(),
                TrialDeclineFeedbackSubmission(reason: reason, hasText: false)
            )
            XCTAssertTrue(questionnaire.isCompleted)
        }
    }

    func testEveryReasonAndSubmitActionAreLocalizedForEveryShippedLocale() {
        let english = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "en"))
        let italian = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "it"))
        let german = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "de"))

        XCTAssertEqual(
            TrialDeclineFeedbackQuestionnaire.availableReasons.map(english.label(for:)),
            [
                "Too expensive",
                "Don’t use it enough",
                "Missing a feature",
                "Just trying it",
                "Prefer another app",
                "Had a technical issue",
                "Other",
            ]
        )
        for content in [english, italian, german] {
            XCTAssertFalse(content.submit.isEmpty)
            XCTAssertEqual(
                TrialDeclineFeedbackQuestionnaire.availableReasons
                    .map(content.label(for:))
                    .filter(\.isEmpty).count,
                0
            )
        }
    }

    func testContentResolvesForEveryShippedLocale() {
        let english = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "en"))
        let italian = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "it"))
        let german = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "de"))

        XCTAssertEqual(english.continueFree, "Continue free")
        XCTAssertEqual(english.skip, "Skip")
        XCTAssertEqual(italian.continueFree, "Continua gratis")
        XCTAssertEqual(italian.skip, "Salta")
        XCTAssertEqual(german.continueFree, "Kostenlos fortfahren")
        XCTAssertEqual(german.skip, "Überspringen")
        XCTAssertFalse(english.title.isEmpty)
        XCTAssertFalse(english.prompt.isEmpty)
        XCTAssertFalse(english.optionalNote.isEmpty)
        XCTAssertFalse(english.thankYou.isEmpty)
    }
}

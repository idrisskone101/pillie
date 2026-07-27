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

    func testOptionalDetailIsVisibleOnlyForMissingFeatureAndOther() {
        for reason in TrialDeclineFeedbackQuestionnaire.availableReasons {
            var questionnaire = TrialDeclineFeedbackQuestionnaire()

            questionnaire.select(reason)

            XCTAssertEqual(
                questionnaire.showsOptionalDetail,
                reason == .missingFeature || reason == .other,
                reason.analyticsValue
            )
        }
    }

    func testOptionalDetailIsCappedAtTheVisible240CharacterLimit() {
        var questionnaire = TrialDeclineFeedbackQuestionnaire()
        questionnaire.select(.missingFeature)

        questionnaire.updateOptionalDetail(String(repeating: "a", count: 241))

        XCTAssertEqual(TrialDeclineFeedbackQuestionnaire.maximumOptionalDetailLength, 240)
        XCTAssertEqual(questionnaire.optionalDetail.count, 240)
    }

    func testSubmissionUsesTrimmedPresenceMetadataForBothOptionalDetailReasons() {
        var missingFeature = TrialDeclineFeedbackQuestionnaire()
        missingFeature.select(.missingFeature)
        missingFeature.updateOptionalDetail("  Dark mode please. \n")

        var other = TrialDeclineFeedbackQuestionnaire()
        other.select(.other)
        other.updateOptionalDetail(" \n\t ")

        XCTAssertTrue(missingFeature.hasOptionalDetail)
        XCTAssertFalse(other.hasOptionalDetail)
        XCTAssertEqual(
            missingFeature.submit(),
            TrialDeclineFeedbackSubmission(reason: .missingFeature, hasText: true)
        )
        XCTAssertEqual(
            other.submit(),
            TrialDeclineFeedbackSubmission(reason: .other, hasText: false)
        )
    }

    func testChangingTheSelectedReasonDiscardsStaleOptionalDetail() {
        var questionnaire = TrialDeclineFeedbackQuestionnaire()
        questionnaire.select(.missingFeature)
        questionnaire.updateOptionalDetail("A private draft")

        questionnaire.select(.other)

        XCTAssertEqual(questionnaire.selectedReason, .other)
        XCTAssertEqual(questionnaire.optionalDetail, "")
        XCTAssertFalse(questionnaire.hasOptionalDetail)
    }

    func testSubmissionDiscardsRawOptionalDetailAfterDerivingPresence() {
        var questionnaire = TrialDeclineFeedbackQuestionnaire()
        questionnaire.select(.missingFeature)
        questionnaire.updateOptionalDetail("A private draft")

        let submission = questionnaire.submit()

        XCTAssertEqual(
            submission,
            TrialDeclineFeedbackSubmission(reason: .missingFeature, hasText: true)
        )
        XCTAssertEqual(questionnaire.optionalDetail, "")
    }

    func testQuestionnaireRetainsDetailOnlyWhileAnEligibleFieldIsUnresolved() {
        for reason in TrialDeclineFeedbackQuestionnaire.availableReasons
            where reason != .missingFeature && reason != .other {
            var questionnaire = TrialDeclineFeedbackQuestionnaire()
            questionnaire.select(reason)

            questionnaire.updateOptionalDetail("A private draft")

            XCTAssertEqual(questionnaire.optionalDetail, "", reason.analyticsValue)
        }

        var completed = TrialDeclineFeedbackQuestionnaire()
        completed.select(.other)
        completed.updateOptionalDetail("A private draft")
        _ = completed.submit()

        completed.updateOptionalDetail("A second private draft")

        XCTAssertEqual(completed.optionalDetail, "")
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

    func testOptionalDetailExperienceIsLocalizedForEveryShippedLocale() {
        let english = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "en"))
        let italian = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "it"))
        let german = TrialDeclineFeedbackContent.make(locale: Locale(identifier: "de"))

        XCTAssertEqual(
            english.optionalDetailPrivacyGuidance,
            "Please don’t include personal health details."
        )
        XCTAssertEqual(
            english.optionalDetailCharacterCount(0),
            "0 of 240 characters"
        )
        for content in [english, italian, german] {
            XCTAssertFalse(content.optionalDetailTitle.isEmpty)
            XCTAssertFalse(content.optionalDetailPlaceholder.isEmpty)
            XCTAssertFalse(content.optionalDetailPrivacyGuidance.isEmpty)
            XCTAssertFalse(content.done.isEmpty)
            XCTAssertFalse(content.optionalDetailCharacterCount(240).isEmpty)
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

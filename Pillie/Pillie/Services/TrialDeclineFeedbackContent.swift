//
//  TrialDeclineFeedbackContent.swift
//  Pillie
//
//  Localized copy for the minimal issue #243 feedback surface.
//

import Foundation

struct TrialDeclineFeedbackContent: Equatable {
    let title: String
    let prompt: String
    let optionalNote: String
    let continueFree: String
    let skip: String
    let thankYou: String

    static func make(locale: Locale = .current) -> TrialDeclineFeedbackContent {
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: locale)
        }

        return TrialDeclineFeedbackContent(
            title: commerce("trial.decline_feedback.title"),
            prompt: commerce("trial.decline_feedback.prompt"),
            optionalNote: commerce("trial.decline_feedback.optional_note"),
            continueFree: commerce("trial.end.continue_free"),
            skip: commerce("trial.decline_feedback.skip"),
            thankYou: commerce("trial.decline_feedback.thank_you")
        )
    }
}

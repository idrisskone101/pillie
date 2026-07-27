//
//  TrialDeclineFeedbackContent.swift
//  Pillie
//
//  Localized copy for the minimal issue #243 feedback surface.
//

import Foundation

enum TrialDeclineFeedbackReason: String, CaseIterable, Equatable, Hashable {
    case tooExpensive = "too_expensive"
    case notUsedEnough = "not_used_enough"
    case missingFeature = "missing_feature"
    case justTrying = "just_trying"
    case preferAnotherApp = "prefer_another_app"
    case technicalIssue = "technical_issue"
    case other

    var analyticsValue: String { rawValue }
}

struct TrialDeclineFeedbackSubmission: Equatable {
    let reason: TrialDeclineFeedbackReason
    let hasText: Bool
}

struct TrialDeclineFeedbackQuestionnaire {
    static let availableReasons = TrialDeclineFeedbackReason.allCases
    static let maximumOptionalDetailLength = 240

    private(set) var selectedReason: TrialDeclineFeedbackReason?
    private(set) var optionalDetail = ""
    private var completion: TrialDeclineFeedbackSubmission?

    var canSubmit: Bool {
        selectedReason != nil && completion == nil
    }

    var showsOptionalDetail: Bool {
        selectedReason == .missingFeature || selectedReason == .other
    }

    var hasOptionalDetail: Bool {
        showsOptionalDetail
            && !optionalDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isCompleted: Bool { completion != nil }

    mutating func select(_ reason: TrialDeclineFeedbackReason) {
        guard completion == nil else { return }
        if selectedReason != reason {
            optionalDetail = ""
        }
        selectedReason = reason
    }

    mutating func updateOptionalDetail(_ detail: String) {
        guard completion == nil, showsOptionalDetail else { return }
        optionalDetail = String(detail.prefix(Self.maximumOptionalDetailLength))
    }

    mutating func submit() -> TrialDeclineFeedbackSubmission? {
        guard let selectedReason, completion == nil else { return nil }
        let submission = TrialDeclineFeedbackSubmission(
            reason: selectedReason,
            hasText: hasOptionalDetail
        )
        optionalDetail = ""
        completion = submission
        return submission
    }
}

struct TrialDeclineFeedbackContent: Equatable {
    let title: String
    let prompt: String
    let optionalNote: String
    let optionalDetailTitle: String
    let optionalDetailPlaceholder: String
    let optionalDetailPrivacyGuidance: String
    let optionalDetailCharacterCountFormat: String
    let done: String
    let continueFree: String
    let skip: String
    let submit: String
    let thankYou: String
    let reasonLabels: [TrialDeclineFeedbackReason: String]

    func label(for reason: TrialDeclineFeedbackReason) -> String {
        reasonLabels[reason] ?? ""
    }

    func optionalDetailCharacterCount(_ count: Int) -> String {
        String(
            format: optionalDetailCharacterCountFormat,
            count,
            TrialDeclineFeedbackQuestionnaire.maximumOptionalDetailLength
        )
    }

    static func make(locale: Locale = .current) -> TrialDeclineFeedbackContent {
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: locale)
        }

        return TrialDeclineFeedbackContent(
            title: commerce("trial.decline_feedback.title"),
            prompt: commerce("trial.decline_feedback.prompt"),
            optionalNote: commerce("trial.decline_feedback.optional_note"),
            optionalDetailTitle: commerce("trial.decline_feedback.detail.title"),
            optionalDetailPlaceholder: commerce("trial.decline_feedback.detail.placeholder"),
            optionalDetailPrivacyGuidance: commerce("trial.decline_feedback.detail.privacy"),
            optionalDetailCharacterCountFormat: commerce(
                "trial.decline_feedback.detail.character_count"
            ),
            done: commerce("trial.decline_feedback.detail.done"),
            continueFree: commerce("trial.end.continue_free"),
            skip: commerce("trial.decline_feedback.skip"),
            submit: commerce("trial.decline_feedback.submit"),
            thankYou: commerce("trial.decline_feedback.thank_you"),
            reasonLabels: [
                .tooExpensive: commerce("trial.decline_feedback.reason.too_expensive"),
                .notUsedEnough: commerce("trial.decline_feedback.reason.not_used_enough"),
                .missingFeature: commerce("trial.decline_feedback.reason.missing_feature"),
                .justTrying: commerce("trial.decline_feedback.reason.just_trying"),
                .preferAnotherApp: commerce("trial.decline_feedback.reason.prefer_another_app"),
                .technicalIssue: commerce("trial.decline_feedback.reason.technical_issue"),
                .other: commerce("trial.decline_feedback.reason.other"),
            ]
        )
    }
}

//
//  ReviewPromptCardContent.swift
//  Pillie
//
//  Pure value-type copy + gating for the Home Review Prompt's Sentiment Gate
//  card (PRD #132 / ADR 0005 / #133). Mirrors `AdaptiveReminderSuggestionCardContent.make`:
//  the factory returns `nil` unless the eligibility decision is `.show`.
//
//  Copy is static and method-agnostic — it never interpolates the contraception
//  method, the Streak value, or an appearance ordinal — so it can be rendered
//  without leaking any of the signals the eligibility check used.
//

struct ReviewPromptCardContent: Equatable {
    /// Step-one Sentiment Gate question.
    let headline: String
    /// Supporting line framing the ask.
    let body: String
    /// Positive-choice CTA that routes to Apple's Native Review Request.
    let positiveTitle: String
    /// Negative-choice CTA that opens the Feedback Escape Hatch (#132).
    let negativeTitle: String

    var visibleCopy: [String] { [headline, body, positiveTitle, negativeTitle] }

    static func make(decision: ReviewPromptEligibility.Decision) -> ReviewPromptCardContent? {
        guard decision == .show else { return nil }
        return ReviewPromptCardContent(
            headline: "Enjoying Pillie?",
            body: "We'd love to hear how it's going for you.",
            positiveTitle: "Yes, I'm enjoying it",
            negativeTitle: "Not really"
        )
    }
}

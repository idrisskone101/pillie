//
//  OpenLine.swift
//  Pillie
//
//  Pure value-type address for the Open Line (PRD #152 / #153): Pillie's
//  always-available two-way support channel, reached from a SUPPORT section in
//  Settings on the user's own initiative. Distinct from `FeedbackEscapeHatch`,
//  which is prompt-driven and reserved for the Sentiment Gate's negative path —
//  neither replaces the other, and this type must never touch that contract.
//
//  Email is the channel deliberately (ADR 0005 precedent: Pillie has no backend,
//  and a reply-able thread *is* the open line), so this owns the externally
//  observable contract: the support recipient and the intent-specific subjects.
//  Subjects are mechanical and stable — the developer's inbox filters pre-triage
//  on them — while the warm row labels live in the UI and may be reworded freely.
//

import Foundation

enum OpenLine {
    /// Pillie support inbox every Open Line intent is addressed to.
    static let recipient = "pillieapp@gmail.com"

    /// Why the user is reaching out. Each intent carries its own stable,
    /// inbox-filterable subject so mail arrives pre-triaged.
    enum Intent {
        /// A feature idea ("Share an Idea" row). Seeds no body at all.
        case suggestion

        /// Subject seeded into the composer; mechanical and PII-free, with an
        /// em dash matching the developer's inbox filters.
        var subject: String {
            switch self {
            case .suggestion:
                return "Pillie — Suggestion"
            }
        }
    }

    /// A `mailto:` URL pre-addressed to Pillie support with the intent's subject.
    /// The suggestion intent seeds no body: the user writes freely, and nothing
    /// this builds can carry message content into a URL, telemetry, or logs.
    /// `nil` only if URL composition ever fails — callers must still surface a
    /// visible fallback, never a silent no-op.
    static func mailURL(for intent: Intent) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [URLQueryItem(name: "subject", value: intent.subject)]
        return components.url
    }
}

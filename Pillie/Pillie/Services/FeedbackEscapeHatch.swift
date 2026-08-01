//
//  FeedbackEscapeHatch.swift
//  Pillie
//
//  Pure value-type address for the Home Review Prompt's negative path (PRD #132 /
//  #134 / ADR 0005). The Sentiment Gate's negative choice diverts unhappy users away
//  from the public App Store rating and into a private email to support, so this
//  owns the one externally-observable contract: a `mailto:` URL pre-addressed to
//  `pillieapp@gmail.com` with a "Pillie feedback" subject.
//
//  ADR 0005 fixes the negative path as `mailto:` only — Pillie has no backend, so
//  feedback is captured solely as the user's own email. The body the user types is
//  private: this helper never seeds or carries it, so nothing it builds can leak
//  feedback text into a URL, telemetry, or logs. `HomeView` opens this URL and marks
//  the prompt answered regardless of whether the device can route it.
//

import Foundation

enum FeedbackEscapeHatch {
    /// Pillie support inbox the negative response is diverted to.
    static let recipient = "pillieapp@gmail.com"
    /// Subject seeded into the composer; intentionally generic and PII-free.
    static let subject = "Pillie feedback"

    /// Kept for locale-aware call sites. The locale deliberately does not affect
    /// this stable inbox-routing contract.
    static func localizedSubject(locale _: Locale = .current) -> String {
        subject
    }

    /// A `mailto:` URL pre-addressed to Pillie support with a "Pillie feedback"
    /// subject and no body. `nil` only if URL composition ever fails — callers
    /// tolerate that the same way they tolerate a device with no Mail account.
    static var mailURL: URL? { mailURL() }

    static func mailURL(locale: Locale = .current) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject)
        ]
        return components.url
    }
}

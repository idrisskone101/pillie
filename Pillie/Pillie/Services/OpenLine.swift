//
//  OpenLine.swift
//  Pillie
//
//  Pure value-type address for the Open Line (PRD #152 / #153 / #154): Pillie's
//  always-available two-way support channel, reached from a SUPPORT section in
//  Settings on the user's own initiative. Distinct from `FeedbackEscapeHatch`,
//  which is prompt-driven and reserved for the Sentiment Gate's negative path —
//  neither replaces the other, and this type must never touch that contract.
//
//  Email is the channel deliberately (ADR 0005 precedent: Pillie has no backend,
//  and a reply-able thread *is* the open line), so this owns the externally
//  observable contract: the support recipient, the intent-specific subjects, and
//  the issue report's seeded body. Subjects are mechanical and stable — the
//  developer's inbox filters pre-triage on them — while the warm row labels live
//  in the UI and may be reworded freely. The issue body carries only injected
//  device/app diagnostics (see `Diagnostics`); routine data never rides it, and
//  what the user types is theirs alone.
//

import Foundation

enum OpenLine {
    /// Pillie support inbox every Open Line intent is addressed to.
    static let recipient = "pillieapp@gmail.com"

    /// Device/app facts seeded into an issue report's footer so the developer can
    /// reproduce without a round-trip. Deliberately holds *plain values only* —
    /// version strings, never routine data — so body composition stays
    /// deterministic and unit-testable. The live values are read from
    /// `Bundle`/`UIDevice` at the call site (`Diagnostics.current`), never here.
    struct Diagnostics: Equatable {
        /// Marketing version, e.g. `"2.0.1"` (CFBundleShortVersionString).
        let appVersion: String
        /// Build number, e.g. `"42"` (CFBundleVersion).
        let build: String
        /// OS version, e.g. `"26.2"` (UIDevice.systemVersion).
        let systemVersion: String
        /// Hardware identifier, e.g. `"iPhone17,1"`.
        let deviceModel: String

        /// Stacked, one fact per line under a separator rule. Values are
        /// interpolated verbatim; nothing about the user's routine appears here.
        var footer: String {
            localizedFooter()
        }

        func localizedFooter(locale: Locale = .current) -> String {
            let deviceLabel = PillieLocalization.string(
                "support.open_line.diagnostics.device",
                locale: locale
            )
            return """
            ———
            App: \(appVersion) (\(build))
            iOS: \(systemVersion)
            \(deviceLabel): \(deviceModel)
            """
        }
    }

    /// Why the user is reaching out. Each intent carries its own stable,
    /// inbox-filterable subject so mail arrives pre-triaged.
    enum Intent {
        /// A feature idea ("Share an Idea" row). Seeds no body at all.
        case suggestion

        /// Something is broken ("Something Not Working?" row). Seeds a warm
        /// invitation plus a device/app diagnostics footer — the injected
        /// `Diagnostics` values and nothing about the user's routine.
        case issueReport(Diagnostics)

        /// Subject seeded into the composer; mechanical and PII-free, with an
        /// em dash matching the developer's inbox filters.
        var subject: String {
            switch self {
            case .suggestion:
                return "Pillie — Suggestion"
            case .issueReport:
                return "Pillie — Issue Report"
            }
        }

        /// Kept for callers that also localize the body. The locale deliberately
        /// does not affect this inbox-routing contract.
        func localizedSubject(locale _: Locale = .current) -> String {
            subject
        }

        /// Text seeded into the composer body. `nil` for suggestion (the user
        /// writes freely). For an issue report, a diagnostics footer only — never
        /// message content, never routine data.
        var body: String? {
            localizedBody()
        }

        func localizedBody(locale: Locale = .current) -> String? {
            switch self {
            case .suggestion:
                return nil
            case .issueReport(let diagnostics):
                return """
                    \(OpenLine.localizedIssueInvitation(locale: locale))

                    \(diagnostics.localizedFooter(locale: locale))
                    """
            }
        }
    }

    /// Warm opener seeded above the diagnostics footer. The register invites the
    /// user to describe what happened *above this line*; it carries no routine
    /// data and can be reworded freely without touching the stable subject.
    static var issueInvitation: String { localizedIssueInvitation() }

    static func localizedIssueInvitation(locale: Locale = .current) -> String {
        PillieLocalization.string("support.open_line.issue_invitation", locale: locale)
    }

    /// The visible fallback shown when the device cannot route a `mailto:` URL
    /// (no Mail account configured, or URL composition failed): an alert that
    /// shows the support address and offers to copy it. This is the Open Line's
    /// no-silent-no-op guarantee (#155) — the strings live here, on the value
    /// type, so both SUPPORT rows present the identical, unit-testable contract.
    enum MailFallback {
        /// Alert title: names what went wrong in plain words.
        static let title = "Couldn't Open Mail"

        /// Alert message: names the situation and shows the address itself, so
        /// the user can reach support by hand even without tapping Copy.
        static let message =
            "It looks like Mail isn't set up on this device. You can reach us anytime at \(OpenLine.recipient)."

        /// Action that writes `addressToCopy` to the pasteboard.
        static let copyActionTitle = "Copy Address"

        /// What Copy Address puts on the pasteboard: the bare support address,
        /// so the view reads the whole fallback contract from this one type.
        static let addressToCopy = OpenLine.recipient

        /// Plain dismissal; the alert already delivered the address visibly.
        static let dismissActionTitle = "OK"
    }

    /// A `mailto:` URL pre-addressed to Pillie support with the intent's subject,
    /// and — for an issue report — its diagnostics body. The suggestion intent
    /// seeds no body: the user writes freely, and nothing this builds can carry
    /// *message content* into a URL, telemetry, or logs. An issue report seeds
    /// only device/app diagnostics, never routine data. `nil` only if URL
    /// composition ever fails — callers must still surface a visible fallback,
    /// never a silent no-op.
    static func mailURL(for intent: Intent, locale: Locale = .current) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        var queryItems = [
            URLQueryItem(name: "subject", value: intent.subject)
        ]
        if let body = intent.localizedBody(locale: locale) {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        components.queryItems = queryItems
        return components.url
    }
}

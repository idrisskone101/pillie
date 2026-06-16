//
//  ProtectionPlanOnboardingContent.swift
//  Pillie
//
//  Static, testable copy for the first two Protection Plan Onboarding screens
//  (Welcome + Analytics Consent), mirroring the Superdesign drafts referenced in
//  issue #73. Keeping copy in value types lets content tests assert the privacy
//  boundary and CTA labels without driving the SwiftUI views.
//

import SwiftUI

/// Copy for the Protection Plan Welcome screen.
struct ProtectionPlanWelcomeContent {
    /// Accessibility description of the hero "moment" panel.
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [eyebrow, title, subtitle, primaryCTA]
    }

    static let `default` = ProtectionPlanWelcomeContent(
        eyebrow: "Your afternoon dose is due — distracting apps stay locked until you check in.",
        title: "Pill reminders that fight back.",
        subtitle: "Pillie blocks your distracting apps until you take your pill — the reminder you can't ignore.",
        primaryCTA: "Build my plan"
    )
}

/// Copy for the Analytics Consent screen, including the three privacy points and
/// both CTA labels.
struct ProtectionPlanAnalyticsConsentContent {
    struct Point: Identifiable, Equatable {
        let symbol: String
        let title: String
        let detail: String

        // Stable, unique identity — each privacy point has a distinct title.
        var id: String { title }
    }

    let title: String
    let body: String
    let points: [Point]
    let allowCTA: String
    let declineCTA: String

    var visibleCopy: [String] {
        [title, body] + points.flatMap { [$0.title, $0.detail] } + [allowCTA, declineCTA]
    }

    static let `default` = ProtectionPlanAnalyticsConsentContent(
        title: "Help improve Pillie?",
        body: "Anonymous usage data helps us fix bugs and improve setup — never anything personal.",
        points: [
            Point(
                symbol: "lock.fill",
                title: "Strict Privacy",
                detail: "We never see your method, reminder times, or typed text."
            ),
            Point(
                symbol: "waveform.path.ecg",
                title: "Technical Health",
                detail: "Just crashes, errors, and which screens get used."
            ),
            Point(
                symbol: "hand.raised.fill",
                title: "No Tracking",
                detail: "Zero ad tracking or third-party data sharing. Ever."
            )
        ],
        allowCTA: "Allow Analytics",
        declineCTA: "Not Now"
    )
}

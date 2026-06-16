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

/// Copy for the Early Value Proof "magic moment" (issue #74). The scene reads as
/// three beats — reminder drift, Pillie's checkpoint, and the prevented
/// distraction — so it proves the product's value before any setup questions,
/// without inventing effectiveness stats or making medical claims.
struct ProtectionPlanEarlyValueProofContent {
    struct Beat: Identifiable, Equatable {
        let symbol: String
        let title: String
        let detail: String

        // Stable identity — each beat has a distinct title.
        var id: String { title }
    }

    let eyebrow: String
    let title: String
    /// Idle (rest) caption shown above the card: states the core value and invites
    /// the slide. The merged subheader — no longer a separate static subtitle.
    let restCue: String
    /// Beat 1: the reminder lands and attention slides toward a distracting app.
    let drift: Beat
    /// Beat 2: Pillie holds that app until the user checks in.
    let checkpoint: Beat
    /// Beat 3: check-in done, the app is released, the drift is averted.
    let resolved: Beat
    /// Primary action label once the pill is taken (kept for semantics/tests).
    let checkInCTA: String
    /// The bottom CTA label at rest — instructs the drag so the demo can't be
    /// skipped with a single tap.
    let dragCTA: String
    /// Advances out of the proof once the moment has played (or immediately in the
    /// static / VoiceOver equivalent).
    let continueCTA: String
    /// Live caption shown while the app is locked, teaching the real check-in
    /// gesture: a quick phone shake.
    let shakeCue: String
    /// The bottom CTA label while the app is locked — the shake instruction.
    let shakeToTakeCTA: String
    let reassurance: String
    /// A single, readable description of the whole resolved narrative for VoiceOver
    /// and the Reduce Motion static state.
    let accessibilitySummary: String

    /// The three beats in narrative order.
    var beats: [Beat] { [drift, checkpoint, resolved] }

    var visibleCopy: [String] {
        [eyebrow, title, restCue]
            + beats.flatMap { [$0.title, $0.detail] }
            + [checkInCTA, dragCTA, continueCTA, shakeCue, shakeToTakeCTA, reassurance, accessibilitySummary]
    }

    static let `default` = ProtectionPlanEarlyValueProofContent(
        eyebrow: "How Pillie helps",
        title: "We'll help you remember.",
        restCue: "Never miss your pill again — taking it becomes the easiest part of your day.",
        drift: Beat(
            symbol: "alarm.fill",
            title: "It's pill time",
            detail: "Your reminder pops up — but your apps are right there, and it's so easy to say \u{201C}later\u{201D}."
        ),
        checkpoint: Beat(
            symbol: "lock.fill",
            title: "Your apps lock",
            detail: "Pillie gently locks them until you take your pill. No nagging — just a little pause."
        ),
        resolved: Beat(
            symbol: "iphone.radiowaves.left.and.right",
            title: "Shake to take your pill",
            detail: "Just shake your phone to take your pill, and your apps unlock right away — easy, and you stayed on track."
        ),
        checkInCTA: "I took my pill",
        dragCTA: "Drag the dot to your apps",
        continueCTA: "Continue",
        shakeCue: "Now shake your phone to take your pill — three quick shakes.",
        shakeToTakeCTA: "Shake to take your pill",
        reassurance: "You choose which apps. We'll handle the timing.",
        accessibilitySummary: "When it's time for your pill, Pillie gently locks your distracting apps until you check in. Give your phone a quick shake to take your pill, and they unlock right away."
    )
}

/// Copy for the Distraction Choices screen (issue #75, Superdesign draft
/// 0344aa3e). Multi-select: the user names what gets in the way after a reminder,
/// including an Other catch-all. The selectable options come from
/// `DistractionChoice`; this struct holds only the surrounding copy.
struct ProtectionPlanDistractionChoicesContent {
    let title: String
    let subtitle: String
    /// Helper shown under the CTA: states the multi-select intent.
    let helper: String
    let primaryCTA: String
    let choices: [DistractionChoice]

    var visibleCopy: [String] {
        [title, subtitle, helper, primaryCTA] + choices.map(\.title)
    }

    static let `default` = ProtectionPlanDistractionChoicesContent(
        title: "Be honest\u{2026}",
        subtitle: "What usually gets in the way after your reminder?",
        helper: "Select all that apply. We'll help you stay focused.",
        primaryCTA: "Continue",
        choices: DistractionChoice.allCases
    )
}

/// Copy for the Delay Consequence screen (issue #75, Superdesign draft aa808d90).
/// Single-select: an emotionally specific, non-medical read on what missing or
/// delaying feels like. Replaces the old PersonalGoal screen in this flow.
struct ProtectionPlanDelayConsequenceContent {
    let title: String
    let subtitle: String
    /// Helper under the title: frames the answer as calibration, not judgement.
    let helper: String
    /// Footnote under the CTA: explains how the answer is used.
    let footnote: String
    let primaryCTA: String
    let choices: [DelayConsequence]

    var visibleCopy: [String] {
        [title, subtitle, helper, footnote, primaryCTA] + choices.map(\.title)
    }

    static let `default` = ProtectionPlanDelayConsequenceContent(
        title: "A quick check-in",
        subtitle: "What does missing or delaying usually feel like?",
        helper: "Understanding your feelings helps us calibrate the right level of support.",
        footnote: "Selected option is used to adjust notification tone and frequency.",
        primaryCTA: "Continue",
        choices: DelayConsequence.allCases
    )
}

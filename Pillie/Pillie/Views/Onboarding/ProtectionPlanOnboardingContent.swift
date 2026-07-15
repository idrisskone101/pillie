//
//  ProtectionPlanOnboardingContent.swift
//  Pillie
//
//  Static, testable copy for the Protection Plan Onboarding screens, mirroring the
//  Superdesign drafts referenced in issues #73–#78. Keeping copy in value types lets
//  content tests assert the privacy boundary and CTA labels without driving the
//  SwiftUI views.
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

/// Copy for the Failure Frequency screen (issue #76, Superdesign draft 12612ffc).
/// Single-select. The display labels are updated to Rarely / A few times a month /
/// Weekly / Multiple times a week, but each option still maps onto the existing
/// `MissFrequency` storage bucket so persisted answers stay compatible.
struct ProtectionPlanFailureFrequencyContent {
    struct Option: Identifiable, Equatable {
        /// The existing storage bucket this label maps onto.
        let bucket: MissFrequency
        let title: String
        let subtitle: String

        var id: String { bucket.rawValue }
    }

    let title: String
    let subtitle: String
    /// Footnote under the CTA: reassures the answer is private.
    let footnote: String
    let primaryCTA: String
    let options: [Option]

    var visibleCopy: [String] {
        [title, subtitle, footnote, primaryCTA] + options.flatMap { [$0.title, $0.subtitle] }
    }

    static let `default` = ProtectionPlanFailureFrequencyContent(
        title: "How often do reminders fail you?",
        subtitle: "Being honest helps us adjust the Pillie Protection level for your needs.",
        footnote: "Your honesty ensures we provide the right level of support. This information is private.",
        primaryCTA: "Continue",
        options: [
            Option(bucket: .rarely, title: "Rarely", subtitle: "Reminders usually work for me"),
            Option(bucket: .sometimes, title: "A few times a month", subtitle: "Occasionally I still forget"),
            Option(bucket: .often, title: "Weekly", subtitle: "At least once every week"),
            Option(bucket: .almostDaily, title: "Multiple times a week", subtitle: "I struggle significantly"),
        ]
    )
}

/// Copy for the Risk Window screen (issue #76, Superdesign draft bae7eb8a).
/// Single-select. In v1 this is personalization / copy only — the clarifier and
/// footnote make clear it does not change the actual blocking schedule.
struct ProtectionPlanRiskWindowContent {
    let title: String
    let subtitle: String
    /// Footnote under the CTA: the single reassurance that this answer is
    /// personalization only and does not drive the blocking schedule. Kept at the
    /// bottom so the question header stays one uncluttered subheader.
    let footnote: String
    let primaryCTA: String
    let choices: [RiskWindow]

    var visibleCopy: [String] {
        [title, subtitle, footnote, primaryCTA]
            + choices.flatMap { [$0.title, $0.subtitle] }
    }

    static let `default` = ProtectionPlanRiskWindowContent(
        title: "Timing is everything",
        subtitle: "When are you most likely to drift into another app?",
        footnote: "This shapes your plan — we don't use it to schedule alarms.",
        primaryCTA: "Continue",
        choices: RiskWindow.allCases
    )
}

/// Copy for the Draft Blocked Apps screen (issue #76, Superdesign drafts f1c3b77e
/// + ed2e2ec4). Multi-select, grouped categories + apps + an Other catch-all. The
/// footnote keeps this clearly separate from the real Screen Time app selection,
/// which happens later with Apple's own picker.
struct ProtectionPlanDraftBlockedAppsContent {
    let title: String
    let subtitle: String
    let categoriesHeader: String
    let appsHeader: String
    /// Header of the live draft-plan summary that fills the lower screen.
    let summaryTitle: String
    /// Empty-state line of the summary, before anything is selected.
    let summaryEmpty: String
    /// Footnote: clarifies this is a draft and real apps are chosen via Screen Time.
    let footnote: String
    let primaryCTA: String
    let categories: [DraftBlockedAppChoice]
    let apps: [DraftBlockedAppChoice]
    let other: DraftBlockedAppChoice

    var visibleCopy: [String] {
        [title, subtitle, categoriesHeader, appsHeader, summaryTitle, summaryEmpty, footnote, primaryCTA]
            + (categories + apps + [other]).map(\.title)
    }

    static let `default` = ProtectionPlanDraftBlockedAppsContent(
        title: "Which apps should Pillie protect pill time from?",
        subtitle: "Choose categories or specific apps to draft your distraction blocklist.",
        categoriesHeader: "Distraction categories",
        appsHeader: "Specific apps",
        summaryTitle: "Your protection draft",
        summaryEmpty: "Tap apps above to start your protection draft.",
        footnote: "This sets your draft preferences. You'll choose specific apps via Screen Time in the final step.",
        primaryCTA: "Save Selections",
        categories: DraftBlockedAppChoice.categories,
        apps: DraftBlockedAppChoice.apps,
        other: .other
    )
}

/// Copy for the Acquisition Source screen (issue #76, Superdesign draft 3e3d657f).
/// Single-select but optional (a Skip path). It stays a broad product signal and is
/// kept distinct from Distraction Choices — "TikTok as a source" is not "TikTok as
/// a distraction".
struct ProtectionPlanAcquisitionSourceContent {
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryCTA: String
    let skipCTA: String
    let choices: [AcquisitionSource]

    var visibleCopy: [String] {
        [eyebrow, title, subtitle, primaryCTA, skipCTA] + choices.map(\.title)
    }

    static let `default` = ProtectionPlanAcquisitionSourceContent(
        eyebrow: "One last thing",
        title: "Where did you find Pillie?",
        subtitle: "Your feedback helps us reach more people who need protection.",
        // Not the end of onboarding — the contraception routine setup follows, so
        // the CTA continues into setup rather than implying it's done.
        primaryCTA: "Continue Setup",
        skipCTA: "Not now",
        choices: AcquisitionSource.allCases
    )
}

/// Copy for the Routine Basics Method screen (issue #77, Superdesign draft
/// c8d8749d). The first routine screen — the user names which contraception routine
/// Pillie should protect. Consolidated from the draft's four stacked lines into a
/// title + question + single footnote so the screen stays uncluttered; each method
/// card pairs `title` with a plain-language `routineDescriptor`.
struct ProtectionPlanRoutineMethodContent {
    let title: String
    let subtitle: String
    let footnote: String
    let primaryCTA: String
    let choices: [ContraceptiveMethod]

    var visibleCopy: [String] {
        [title, subtitle, footnote, primaryCTA]
            + choices.flatMap { [$0.title, $0.routineDescriptor] }
    }

    static let `default` = ProtectionPlanRoutineMethodContent(
        title: "The core of it",
        subtitle: "What routine should Pillie protect?",
        footnote: "Your plan adapts to how you take it. You can change this anytime.",
        primaryCTA: "Continue",
        choices: ContraceptiveMethod.allCases
    )
}

/// Copy for the Routine Basics Details screen (issue #77, Superdesign draft
/// b9b281e6). Replaces the legacy seven-card regimen form: a coarse cycle-position
/// toggle anchors the exact day, and only the common regimens show up front with the
/// rest behind "More options". The view chooses the method-specific section (pill
/// regimen picker vs. patch/ring schedule rules); this struct holds the shared copy.
struct ProtectionPlanRoutineDetailsContent {
    let title: String
    let subtitle: String
    let cyclePositionHeader: String
    let regimenHeader: String
    /// Disclosure that reveals the optional exact cycle-day adjustment.
    let editExactDayLabel: String
    /// Label for the disclosure that reveals the less common regimens.
    let moreLabel: String
    let footnote: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [title, subtitle, cyclePositionHeader, regimenHeader, editExactDayLabel, moreLabel, footnote, primaryCTA]
            + CyclePosition.allCases.map(\.title)
    }

    static let `default` = ProtectionPlanRoutineDetailsContent(
        title: "Where are you in your routine?",
        subtitle: "How far into your cycle are you?",
        cyclePositionHeader: "Where are you now?",
        regimenHeader: "Pill regimen",
        editExactDayLabel: "Edit exact day",
        moreLabel: "More options",
        footnote: "This keeps your reminders in sync with your cycle — for tracking, not medical advice.",
        primaryCTA: "Continue"
    )
}

/// Copy for the Reminder Time screen (issue #77, Superdesign draft ec61e147). Picks
/// the Due Action Time through the existing production reminder model, kept lean —
/// the screen leads with the picker and a single method-aware line.
struct ProtectionPlanReminderTimeContent {
    let title: String
    let subtitle: String
    /// Eyebrow above the time wheel, naming the Due Action Time concept once rather
    /// than repeating it in a separate helper line.
    let pickerLabel: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [title, subtitle, pickerLabel, primaryCTA]
    }

    static let `default` = ProtectionPlanReminderTimeContent(
        title: "The golden hour",
        subtitle: "When should Pillie step in?",
        pickerLabel: "Due Action Time",
        primaryCTA: "Set Reminder Time"
    )
}

/// Static labels for the Personalized Diagnosis / Draft Pill Protection Plan reveal
/// (issue #78, Superdesign draft 48637486). The *dynamic*, personalized values
/// (Primary Distraction, Due Action Time, method-aware lead line) come from
/// `ProtectionPlanDiagnosis`; this struct holds only the surrounding static chrome.
/// Deliberately carries no scores, stats, or medical framing — the reveal must read
/// as a personalized plan, not a clinical readout.
struct ProtectionPlanDiagnosisContent {
    /// Step label above the headline, e.g. "FINAL STEP".
    let eyebrow: String
    /// Headline shown during the analyzing beat (present-progressive).
    let analyzingTitle: String
    /// Sub-line shown while the scan plays.
    let analyzingSubtitle: String
    /// Header above the plan's strategy points.
    let strategyHeader: String
    let protectedAppsHeader: String
    /// Handwritten accent under the plan ("you're all set!").
    let handNote: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [eyebrow, analyzingTitle, analyzingSubtitle, strategyHeader, protectedAppsHeader, handNote, primaryCTA]
    }

    static let `default` = ProtectionPlanDiagnosisContent(
        eyebrow: "FINAL STEP",
        analyzingTitle: "Building your protection plan",
        analyzingSubtitle: "Analyzing your habits and focus zones",
        strategyHeader: "How it protects you",
        protectedAppsHeader: "Protected apps",
        handNote: "you're all set!",
        primaryCTA: "Activate my plan"
    )
}

/// Copy for the Mechanism Proof (issue #78, Superdesign drafts c3e8eb96 / 6f6cedb8 /
/// f1c2c9b9). Shows the three-step loop — reminder rings, distracting apps lock, mark
/// taken to unlock — replayably and with a readable static state. Method-aware so a
/// Patch or Ring user never sees pill wording. The Superdesign drafts' "98% of users"
/// stat and medical-adherence framing are intentionally dropped: the acceptance
/// criteria forbid fake stats and medical-risk claims.
struct ProtectionPlanMechanismProofContent {
    struct Step: Identifiable, Equatable {
        /// The loop phase label, e.g. "TRIGGER".
        let phase: String
        let title: String
        let detail: String
        let symbol: String

        // Stable identity — each step has a distinct phase.
        var id: String { phase }
    }

    let headline: String
    /// Beat 1: the reminder fires.
    let trigger: Step
    /// Beat 2: the chosen apps are locked.
    let enforce: Step
    /// Beat 3: checking in unlocks them.
    let release: Step
    /// Badge shown over a sealed app tile.
    let lockedLabel: String
    /// Primary action that unlocks the demo (method-aware, past tense).
    let markTakenCTA: String
    /// Restarts the loop so the proof is replayable.
    let replayCTA: String
    /// Advances to the paywall.
    let continueCTA: String
    let footer: String
    /// A single readable line describing the whole loop for VoiceOver / Reduce Motion.
    let accessibilitySummary: String

    /// The three beats in loop order.
    var steps: [Step] { [trigger, enforce, release] }

    var visibleCopy: [String] {
        [headline]
            + steps.flatMap { [$0.phase, $0.title, $0.detail] }
            + [lockedLabel, markTakenCTA, replayCTA, continueCTA, footer, accessibilitySummary]
    }

    init(method: ContraceptiveMethod) {
        let language = MethodActionLanguage(method: method)
        let action = language.actionPhrase
        let capitalAction = action.prefix(1).uppercased() + action.dropFirst()
        let moment = language.momentLabel

        headline = "The lock only opens after you \(action)."
        trigger = Step(
            phase: "TRIGGER",
            title: "Reminder rings",
            detail: "A gentle, persistent nudge when it's \(moment).",
            symbol: "bell.fill"
        )
        enforce = Step(
            phase: "ENFORCE",
            title: "Distracting apps lock",
            detail: "Your chosen apps stay sealed \u{2014} no scrolling past the reminder.",
            symbol: "lock.fill"
        )
        release = Step(
            phase: "RELEASE",
            title: "Tap to unlock",
            detail: "\(capitalAction) and everything opens right back up.",
            symbol: "checkmark.seal.fill"
        )
        lockedLabel = "Locked"
        markTakenCTA = Self.markTakenLabel(for: method)
        replayCTA = "Replay"
        continueCTA = "Continue"
        footer = "Part of your Pillie Protection Plan."
        accessibilitySummary = "When it's \(moment), Pillie rings a reminder and locks your distracting apps. \(capitalAction) to unlock them instantly."
    }

    private static func markTakenLabel(for method: ContraceptiveMethod) -> String {
        switch method {
        case .pill: return "I took my pill"
        case .patch: return "I changed my patch"
        case .ring: return "I checked my ring"
        }
    }
}

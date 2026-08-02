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
    let reminderTitle: String
    let reminderSubtitle: String
    let appsTitle: String
    let appsAvailableDetail: String
    let appsLockedDetail: String
    let title: String
    let subtitle: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [
            eyebrow,
            reminderTitle,
            reminderSubtitle,
            appsTitle,
            appsAvailableDetail,
            appsLockedDetail,
            title,
            subtitle,
            primaryCTA,
        ]
    }

    static var `default`: ProtectionPlanWelcomeContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanWelcomeContent {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let sampleTime = calendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1, hour: 14, minute: 0)
        )?.formatted(Date.FormatStyle().hour().minute().locale(locale)) ?? "14:00"

        return ProtectionPlanWelcomeContent(
            eyebrow: PillieLocalization.string("onboarding.welcome.eyebrow", locale: locale),
            reminderTitle: PillieLocalization.string(
                "onboarding.welcome.demo.reminder_title",
                locale: locale
            ),
            reminderSubtitle: PillieLocalization.formatted(
                "onboarding.welcome.demo.reminder_time",
                locale: locale,
                arguments: sampleTime
            ),
            appsTitle: PillieLocalization.string(
                "onboarding.welcome.demo.apps_title",
                locale: locale
            ),
            appsAvailableDetail: PillieLocalization.string(
                "onboarding.welcome.demo.apps_open",
                locale: locale
            ),
            appsLockedDetail: PillieLocalization.string(
                "onboarding.welcome.demo.apps_locked",
                locale: locale
            ),
            title: PillieLocalization.string("onboarding.welcome.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.welcome.subtitle", locale: locale),
            primaryCTA: PillieLocalization.string("global.action.get_started", locale: locale)
        )
    }
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
    private let locale: Locale
    let sampleTimeText: String
    let appsLabel: String
    let lockedLabel: String
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
    /// The bottom primary CTA label at rest, preserving the optional drag demo.
    let dragCTA: String
    /// Visible tap-only escape from the optional interaction.
    let skipDemoCTA: String
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
        [eyebrow, title, sampleTimeText, appsLabel, lockedLabel, restCue]
            + beats.flatMap { [$0.title, $0.detail] }
            + [checkInCTA, dragCTA, skipDemoCTA, continueCTA, shakeCue, shakeToTakeCTA, reassurance, accessibilitySummary]
    }

    func shakeProgress(current: Int, total: Int) -> String {
        PillieLocalization.formatted(
            "onboarding.blocking_demo.shake_progress",
            locale: locale,
            arguments: Int64(current), Int64(total)
        )
    }

    static var `default`: ProtectionPlanEarlyValueProofContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanEarlyValueProofContent {
        let title = PillieLocalization.string("onboarding.blocking_demo.title", locale: locale)
        let body = PillieLocalization.string("onboarding.blocking_demo.body", locale: locale)
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let sampleTime = calendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1, hour: 14, minute: 0)
        )?.formatted(Date.FormatStyle().hour().minute().locale(locale)) ?? "14:00"
        return ProtectionPlanEarlyValueProofContent(
            eyebrow: PillieLocalization.string("onboarding.demo.title", locale: locale),
            title: title,
            locale: locale,
            sampleTimeText: sampleTime,
            appsLabel: PillieLocalization.string(
                "onboarding.blocking_demo.apps_label",
                locale: locale
            ),
            lockedLabel: PillieLocalization.string(
                "onboarding.blocking_demo.locked_label",
                locale: locale
            ),
            restCue: body,
            drift: Beat(
                symbol: "alarm.fill",
                title: PillieLocalization.string("onboarding.demo.step.reminder", locale: locale),
                detail: PillieLocalization.string("onboarding.demo.remind_log", locale: locale)
            ),
            checkpoint: Beat(
                symbol: "lock.fill",
                title: PillieLocalization.string("onboarding.blocking_demo.apps_blocked", locale: locale),
                detail: PillieLocalization.string("onboarding.blocking_demo.apps_blocked_body", locale: locale)
            ),
            resolved: Beat(
                symbol: "iphone.radiowaves.left.and.right",
                title: PillieLocalization.string("onboarding.blocking_demo.apps_unlock", locale: locale),
                detail: PillieLocalization.string("onboarding.blocking_demo.apps_unlock_body", locale: locale)
            ),
            checkInCTA: PillieLocalization.string("notification.action.complete", locale: locale),
            dragCTA: PillieLocalization.string("onboarding.blocking_demo.drag_title", locale: locale),
            skipDemoCTA: PillieLocalization.string("global.action.not_now", locale: locale),
            continueCTA: PillieLocalization.string("global.action.continue", locale: locale),
            shakeCue: PillieLocalization.string("onboarding.blocking_demo.shake_body", locale: locale),
            shakeToTakeCTA: PillieLocalization.string("onboarding.blocking_demo.shake_title", locale: locale),
            reassurance: PillieLocalization.string("onboarding.demo.explainer", locale: locale),
            accessibilitySummary: "\(title) \(body)"
        )
    }
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
    let desiredOutcomeTitle: String
    let desiredOutcomeSubtitle: String
    let desiredOutcomes: [DelayConsequence]

    var visibleCopy: [String] {
        [title, subtitle, helper, desiredOutcomeTitle, desiredOutcomeSubtitle, primaryCTA]
            + choices.map(\.title)
            + desiredOutcomes.map(\.desiredOutcomeTitle)
    }

    static var `default`: ProtectionPlanDistractionChoicesContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanDistractionChoicesContent {
        ProtectionPlanDistractionChoicesContent(
            title: PillieLocalization.string("onboarding.personalise.pain.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.personalise.pain.subtitle", locale: locale),
            helper: PillieLocalization.string("onboarding.personalise.distraction.subtitle", locale: locale),
            primaryCTA: PillieLocalization.string("global.action.continue", locale: locale),
            choices: DistractionChoice.allCases,
            desiredOutcomeTitle: PillieLocalization.string("onboarding.personalise.outcome.title", locale: locale),
            desiredOutcomeSubtitle: PillieLocalization.string("onboarding.personalise.outcome.subtitle", locale: locale),
            desiredOutcomes: DelayConsequence.allCases
        )
    }
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
    let riskWindowTitle: String
    let riskWindowSubtitle: String
    let riskWindowFootnote: String
    let riskWindows: [RiskWindow]

    var visibleCopy: [String] {
        [title, subtitle, footnote, riskWindowTitle, riskWindowSubtitle, riskWindowFootnote, primaryCTA]
            + options.flatMap { [$0.title, $0.subtitle] }
            + riskWindows.flatMap { [$0.title, $0.subtitle] }
    }

    static var `default`: ProtectionPlanFailureFrequencyContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanFailureFrequencyContent {
        ProtectionPlanFailureFrequencyContent(
        title: PillieLocalization.string("onboarding.frequency.title", locale: locale),
        subtitle: PillieLocalization.string("onboarding.frequency.subtitle", locale: locale),
        footnote: PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
        primaryCTA: PillieLocalization.string("global.action.continue", locale: locale),
        options: [
            Option(bucket: .rarely, title: PillieLocalization.string("onboarding.frequency.rarely.title", locale: locale), subtitle: PillieLocalization.string("onboarding.frequency.rarely.subtitle", locale: locale)),
            Option(bucket: .sometimes, title: PillieLocalization.string("onboarding.frequency.sometimes.title", locale: locale), subtitle: PillieLocalization.string("onboarding.frequency.sometimes.subtitle", locale: locale)),
            Option(bucket: .often, title: PillieLocalization.string("onboarding.frequency.often.title", locale: locale), subtitle: PillieLocalization.string("onboarding.frequency.often.subtitle", locale: locale)),
            Option(bucket: .almostDaily, title: PillieLocalization.string("onboarding.frequency.daily.title", locale: locale), subtitle: PillieLocalization.string("onboarding.frequency.daily.subtitle", locale: locale)),
        ],
        riskWindowTitle: PillieLocalization.string("onboarding.risk_window.title", locale: locale),
        riskWindowSubtitle: PillieLocalization.string("onboarding.risk_window.subtitle", locale: locale),
        riskWindowFootnote: PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
        riskWindows: RiskWindow.allCases
    )
    }
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

    static var `default`: ProtectionPlanAcquisitionSourceContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanAcquisitionSourceContent {
        ProtectionPlanAcquisitionSourceContent(
        eyebrow: PillieLocalization.string("onboarding.welcome.next_action", locale: locale),
        title: PillieLocalization.string("onboarding.acquisition.title", locale: locale),
        subtitle: PillieLocalization.string("onboarding.acquisition.subtitle", locale: locale),
        // Not the end of onboarding — the contraception routine setup follows, so
        // the CTA continues into setup rather than implying it's done.
        primaryCTA: PillieLocalization.string("global.action.continue", locale: locale),
        skipCTA: PillieLocalization.string("global.action.not_now", locale: locale),
        choices: AcquisitionSource.allCases
    )
    }
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

    static var `default`: ProtectionPlanRoutineMethodContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanRoutineMethodContent {
        ProtectionPlanRoutineMethodContent(
            title: PillieLocalization.string("onboarding.method.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.method.subtitle", locale: locale),
            footnote: PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
            primaryCTA: PillieLocalization.string("global.action.continue", locale: locale),
            choices: ContraceptiveMethod.allCases
        )
    }
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

    static var `default`: ProtectionPlanRoutineDetailsContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanRoutineDetailsContent {
        ProtectionPlanRoutineDetailsContent(
            title: PillieLocalization.string("onboarding.cycle_position.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.cycle_position.subtitle", locale: locale),
            cyclePositionHeader: PillieLocalization.string("onboarding.cycle_position.title", locale: locale),
            regimenHeader: PillieLocalization.string("onboarding.regimen.title", locale: locale),
            editExactDayLabel: PillieLocalization.string("global.action.edit", locale: locale),
            moreLabel: PillieLocalization.string("onboarding.regimen.custom", locale: locale),
            footnote: PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
            primaryCTA: PillieLocalization.string("global.action.continue", locale: locale)
        )
    }
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

    static var `default`: ProtectionPlanReminderTimeContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanReminderTimeContent {
        ProtectionPlanReminderTimeContent(
            title: PillieLocalization.string("onboarding.reminder_time.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.reminder_time.subtitle", locale: locale),
            pickerLabel: PillieLocalization.string("onboarding.plan.schedule", locale: locale),
            primaryCTA: PillieLocalization.string("onboarding.permission.cta", locale: locale)
        )
    }
}

/// Static labels for the Personalized Diagnosis / Draft Pill Protection Plan reveal
/// (issue #78, Superdesign draft 48637486). The *dynamic*, personalized values
/// (Primary Distraction, Due Action Time, method-aware lead line) come from
/// `ProtectionPlanDiagnosis`; this struct holds only the surrounding static chrome.
/// Deliberately carries no scores, stats, or medical framing — the reveal must read
/// as a personalized plan, not a clinical readout.
struct ProtectionPlanDiagnosisContent {
    private let locale: Locale
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

    func analyzingAccessibilityLabel(signals: [String]) -> String {
        PillieLocalization.formatted(
            "onboarding.plan.detected_accessibility",
            locale: locale,
            arguments: analyzingTitle, signals.joined(separator: ", ")
        )
    }

    static var `default`: ProtectionPlanDiagnosisContent { localized() }

    static func localized(locale: Locale = .current) -> ProtectionPlanDiagnosisContent {
        ProtectionPlanDiagnosisContent(
            locale: locale,
            eyebrow: PillieLocalization.string("onboarding.welcome.next_action", locale: locale),
            analyzingTitle: PillieLocalization.string("onboarding.plan.title", locale: locale),
            analyzingSubtitle: PillieLocalization.string("onboarding.plan.subtitle", locale: locale),
            strategyHeader: PillieLocalization.string("onboarding.plan.support", locale: locale),
            protectedAppsHeader: PillieLocalization.string(
                "onboarding.plan.protected_apps_header",
                locale: locale
            ),
            handNote: PillieLocalization.string(
                "onboarding.plan.ready_accent",
                locale: locale
            ),
            primaryCTA: PillieLocalization.string("global.action.continue", locale: locale)
        )
    }
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

    let eyebrow: String
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
    let unlockedConfirmation: String
    let replayAccessibilityHint: String
    /// A single readable line describing the whole loop for VoiceOver / Reduce Motion.
    let accessibilitySummary: String

    /// The three beats in loop order.
    var steps: [Step] { [trigger, enforce, release] }

    var visibleCopy: [String] {
        [eyebrow, headline]
            + steps.flatMap { [$0.phase, $0.title, $0.detail] }
            + [
                lockedLabel,
                markTakenCTA,
                replayCTA,
                continueCTA,
                footer,
                unlockedConfirmation,
                replayAccessibilityHint,
                accessibilitySummary,
            ]
    }

    init(method: ContraceptiveMethod, locale: Locale = .current) {
        func localized(_ key: String) -> String {
            PillieLocalization.string(key, locale: locale)
        }

        eyebrow = localized("onboarding.mechanism.eyebrow")
        headline = localized("onboarding.mechanism.headline")
        trigger = Step(
            phase: localized("onboarding.mechanism.trigger.phase"),
            title: localized("onboarding.mechanism.trigger.title"),
            detail: localized("onboarding.mechanism.trigger.detail"),
            symbol: "bell.fill"
        )
        enforce = Step(
            phase: localized("onboarding.mechanism.enforce.phase"),
            title: localized("onboarding.mechanism.enforce.title"),
            detail: localized("onboarding.mechanism.enforce.detail"),
            symbol: "lock.fill"
        )
        release = Step(
            phase: localized("onboarding.mechanism.release.phase"),
            title: localized("onboarding.mechanism.release.title"),
            detail: localized("onboarding.mechanism.release.detail"),
            symbol: "checkmark.seal.fill"
        )
        lockedLabel = localized("onboarding.mechanism.locked")
        markTakenCTA = localized(Self.markTakenKey(for: method))
        replayCTA = localized("onboarding.mechanism.replay")
        continueCTA = localized("onboarding.mechanism.continue")
        footer = localized("onboarding.mechanism.footer")
        unlockedConfirmation = localized("onboarding.mechanism.unlocked")
        replayAccessibilityHint = localized("onboarding.mechanism.replay_hint")
        accessibilitySummary = localized("onboarding.mechanism.accessibility_summary")
    }

    private static func markTakenKey(for method: ContraceptiveMethod) -> String {
        switch method {
        case .pill: return "onboarding.mechanism.mark.pill"
        case .patch: return "onboarding.mechanism.mark.patch"
        case .ring: return "onboarding.mechanism.mark.ring"
        }
    }
}

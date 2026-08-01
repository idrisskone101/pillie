//
//  ProtectionPlanDiagnosis.swift
//  Pillie
//
//  The deep, UI-free core of the Personalized Diagnosis screen (PRD #72, issue
//  #78). The user's committed calibration answers are turned into a Draft Pill
//  Protection Plan: a deterministic Primary Distraction, a short protected-apps
//  list, and method-aware, privacy-safe copy.
//
//  Everything here is a pure value type so the derivation and copy are fully
//  unit-testable without any reference-type / main-actor deinit hazards. The view
//  assembles the inputs from `PillStore` + the onboarding model and hands them to
//  `ProtectionPlanDiagnosis`, which carries the test coverage.
//

import Foundation

/// A canonical, named distracting app Pillie can surface by name in the plan. Both
/// `DistractionChoice` and `DraftBlockedAppChoice` app answers map onto this single
/// vocabulary so the derivation has one priority order to reason about.
///
/// Declaration order *is* the canonical priority (scroll-first apps outrank
/// Messages), so a tie always resolves the same way.
enum DistractionApp: String, CaseIterable, Equatable {
    case tiktok
    case instagram
    case snapchat
    case youtube
    case x
    case messages

    var displayName: String {
        localizedDisplayName()
    }

    func localizedDisplayName(locale: Locale = .current) -> String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .snapchat: return "Snapchat"
        case .youtube: return "YouTube"
        case .x: return "X"
        case .messages:
            return PillieLocalization.string(
                "onboarding.personalise.choice.messages",
                locale: locale
            )
        }
    }

    /// A generic, App-Store-safe SF Symbol — never a brand mark, but chosen to evoke
    /// each app's category and to stay visually distinct from its neighbours on the
    /// protected-apps row.
    var symbolName: String {
        switch self {
        case .tiktok: return "music.note"                          // short-form sound
        case .instagram: return "camera.fill"                      // photos
        case .snapchat: return "camera.viewfinder"                 // snap / camera-first
        case .youtube: return "play.rectangle.fill"               // video
        case .x: return "text.bubble.fill"                         // posts
        case .messages: return "bubble.left.and.bubble.right.fill" // conversation
        }
    }
}

/// The single most specific distraction surfaced in the Draft Pill Protection Plan,
/// or a safe generic fallback when the user only gave broad / non-app answers
/// (categories, "I just forget", Other, or nothing).
enum PrimaryDistraction: Equatable {
    case app(DistractionApp)
    case generic

    /// User-facing name. The generic fallback reads naturally inside a sentence.
    var displayName: String {
        localizedDisplayName()
    }

    func localizedDisplayName(locale: Locale = .current) -> String {
        switch self {
        case .app(let app): return app.localizedDisplayName(locale: locale)
        case .generic:
            return PillieLocalization.string("onboarding.plan.main_risk.generic", locale: locale)
        }
    }

    /// Whether a concrete app was identified (vs. the generic fallback).
    var isSpecific: Bool {
        if case .app = self { return true }
        return false
    }
}

/// Deterministic derivation from the committed calibration answers. Pure functions,
/// no stored state — the same answers always produce the same plan.
enum ProtectionPlanDiagnosisEngine {
    /// The user's Primary Distraction. The "which apps should Pillie block" answer
    /// (`draftBlockedApps`) is the most direct signal, so a named app there wins;
    /// otherwise a named app from Distraction Choices is used; otherwise we fall back
    /// to the safe generic framing.
    static func primaryDistraction(
        distractionChoices: Set<DistractionChoice>,
        draftBlockedApps: Set<DraftBlockedAppChoice>
    ) -> PrimaryDistraction {
        if let top = canonical(namedApps(in: draftBlockedApps)).first {
            return .app(top)
        }
        if let top = canonical(namedApps(in: distractionChoices)).first {
            return .app(top)
        }
        return .generic
    }

    /// A short, canonical-ordered, de-duplicated list of named apps to show as
    /// "Protected apps" tiles (and on the Mechanism Proof). Drawn from both answers,
    /// capped so the reveal stays scannable. Empty when no concrete app was chosen.
    static func protectedApps(
        distractionChoices: Set<DistractionChoice>,
        draftBlockedApps: Set<DraftBlockedAppChoice>
    ) -> [DistractionApp] {
        let mentioned = Set(namedApps(in: draftBlockedApps) + namedApps(in: distractionChoices))
        return Array(canonical(mentioned).prefix(3))
    }

    // MARK: - Mapping onto the canonical vocabulary

    private static func namedApps(in choices: Set<DistractionChoice>) -> [DistractionApp] {
        choices.compactMap { choice in
            switch choice {
            case .tiktok: return .tiktok
            case .instagram: return .instagram
            case .youtube: return .youtube
            case .messages: return .messages
            case .snooze, .busy, .forget, .other: return nil
            }
        }
    }

    private static func namedApps(in choices: Set<DraftBlockedAppChoice>) -> [DistractionApp] {
        choices.compactMap { choice in
            switch choice {
            case .tiktok: return .tiktok
            case .instagram: return .instagram
            case .youtube: return .youtube
            case .x: return .x
            case .snapchat: return .snapchat
            case .messages: return .messages
            case .shortVideos, .socialFeeds, .games, .other: return nil
            }
        }
    }

    /// Sorts (and implicitly de-duplicates against the canonical list) by priority.
    private static func canonical<S: Sequence>(_ apps: S) -> [DistractionApp]
    where S.Element == DistractionApp {
        let set = Set(apps)
        return DistractionApp.allCases.filter(set.contains)
    }
}

/// Method-aware presentation copy for the narrow cycle tile in the diagnosis.
/// The visual value stays compact enough for one line while VoiceOver retains the
/// complete regimen or routine detail that the tile previously displayed.
struct ProtectionPlanCycleStatContent: Equatable {
    let symbolName: String
    let compactValue: String
    let accessibilityValue: String
    let label: String

    static func make(
        method: ContraceptiveMethod,
        regimen: PillPack.PillRegimenPreset,
        activeDays: Int,
        breakDays: Int,
        locale: Locale = .current
    ) -> ProtectionPlanCycleStatContent {
        let label = PillieLocalization.string(
            "onboarding.plan.current_cycle",
            locale: locale
        )

        switch method {
        case .pill:
            return ProtectionPlanCycleStatContent(
                symbolName: "pills.fill",
                compactValue: "\(activeDays)/\(breakDays)",
                accessibilityValue: regimen.localizedScheduleSummary(locale: locale),
                label: label
            )
        case .patch:
            return ProtectionPlanCycleStatContent(
                symbolName: "bandage.fill",
                compactValue: method.localizedTitle(locale: locale),
                accessibilityValue: method.localizedRoutineDescriptor(locale: locale),
                label: label
            )
        case .ring:
            return ProtectionPlanCycleStatContent(
                symbolName: "circle.circle",
                compactValue: method.localizedTitle(locale: locale),
                accessibilityValue: method.localizedRoutineDescriptor(locale: locale),
                label: label
            )
        }
    }
}

/// The Draft Pill Protection Plan copy, built from the derived plan + the user's
/// method and Due Action Time. A pure value type — all strings are deterministic
/// and method-aware (never leaking pill wording into a Patch or Ring plan).
struct ProtectionPlanDiagnosis: Equatable {
    let primaryDistraction: PrimaryDistraction
    let protectedApps: [DistractionApp]
    let method: ContraceptiveMethod
    /// Pre-formatted Due Action Time, e.g. "8:00 AM".
    let dueActionTimeText: String
    let riskWindow: RiskWindow?
    /// Extra committed answers, surfaced as "we read your answers" chips during the
    /// analyzing beat. They reflect the user's own selections — never invented.
    let distractionChoices: Set<DistractionChoice>
    let delayConsequence: DelayConsequence?
    let missFrequency: MissFrequency?
    let locale: Locale

    init(
        primaryDistraction: PrimaryDistraction,
        protectedApps: [DistractionApp],
        method: ContraceptiveMethod,
        dueActionTimeText: String,
        riskWindow: RiskWindow?,
        distractionChoices: Set<DistractionChoice> = [],
        delayConsequence: DelayConsequence? = nil,
        missFrequency: MissFrequency? = nil,
        locale: Locale = .current
    ) {
        self.primaryDistraction = primaryDistraction
        self.protectedApps = protectedApps
        self.method = method
        self.dueActionTimeText = dueActionTimeText
        self.riskWindow = riskWindow
        self.distractionChoices = distractionChoices
        self.delayConsequence = delayConsequence
        self.missFrequency = missFrequency
        self.locale = locale
    }

    private var language: MethodActionLanguage { MethodActionLanguage(method: method) }

    /// The capitalised method word used in the plan name.
    private var planWord: String {
        method.localizedTitle(locale: locale)
    }

    /// Lowercase method word for in-sentence headlines, e.g. "pill" in
    /// "Your pill plan is ready." Stays method-aware (never leaks pill into patch/ring).
    var methodWord: String { planWord.lowercased() }

    var headline: String {
        PillieLocalization.string("onboarding.plan.title", locale: locale)
    }

    /// The personalised one-liner under the headline. Names the app + Due Action Time
    /// when a specific distraction was identified; frames apps broadly otherwise.
    var leadLine: String {
        PillieLocalization.string("onboarding.plan.subtitle", locale: locale)
    }

    /// "Main risk" card value.
    var mainRiskValue: String {
        primaryDistraction.isSpecific
            ? primaryDistraction.localizedDisplayName(locale: locale)
            : PillieLocalization.string("onboarding.plan.main_risk.generic", locale: locale)
    }

    /// "Window" card value — the Due Action Time.
    var windowValue: String { dueActionTimeText }

    /// "Protection" card value.
    var protectionModeValue: String {
        PillieLocalization.string("onboarding.plan.support", locale: locale)
    }

    /// The protected-apps summary line. Falls back to a broad phrase when no concrete
    /// app was chosen, so the plan never reads as empty.
    var protectedAppsLabel: String {
        guard !protectedApps.isEmpty else {
            return PillieLocalization.string("onboarding.blocking_setup.title", locale: locale)
        }
        return protectedApps
            .map { $0.localizedDisplayName(locale: locale) }
            .joined(separator: ", ")
    }

    /// A generic, method-aware description of the core lock mechanism that stands on
    /// its own — independent of any specific apps the user named. Used by the plan's
    /// app-lock card so the reveal still communicates "your distracting apps stay
    /// locked until you check in" even when no app list was ever collected.
    var lockMechanismSummary: String {
        PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale)
    }

    /// The signals Pillie "detected" from the calibration, shown as chips during the
    /// analyzing beat. Drawn from the user's own answers across the whole flow — the
    /// primary distraction, Due Action Time, risk window, how often reminders slip,
    /// how missing feels, and their specific habits — so the plan reads as built from
    /// what they told us. Deduped and capped so the scan stays readable.
    var detectedSignals: [String] {
        var raw: [String] = [mainRiskValue, windowValue]
        if let riskWindow { raw.append(riskWindow.localizedTitle(locale: locale)) }
        raw.append(contentsOf: distractionChoices.map { $0.localizedTitle(locale: locale) })

        var seen = Set<String>()
        var unique: [String] = []
        for chip in raw where seen.insert(chip).inserted {
            unique.append(chip)
        }
        return Array(unique.prefix(6))
    }

    /// Short, friendly chips for the "I snooze it / I'm busy / I just forget" habits.
    private var distractionHabitChips: [String] {
        var chips: [String] = []
        if distractionChoices.contains(.snooze) { chips.append("Snoozes reminders") }
        if distractionChoices.contains(.busy) { chips.append("Busy mornings") }
        if distractionChoices.contains(.forget) { chips.append("Easy to forget") }
        return chips
    }

    /// A short, non-judgmental read of how often reminders slip.
    private var missFrequencyChip: String? {
        switch missFrequency {
        case .rarely: return "Rarely slips"
        case .sometimes: return "Occasional slips"
        case .often: return "Weekly slips"
        case .almostDaily: return "Needs daily backup"
        case nil: return nil
        }
    }

    /// A short, non-medical read of how missing feels (skips "I don't care much").
    private var delayConsequenceChip: String? {
        switch delayConsequence {
        case .stressful: return "Late = stress"
        case .annoying: return "Hates slipping"
        case .scary: return "Wants peace of mind"
        case .overthink: return "Overthinks gaps"
        case .doubleCheck: return "Likes to be sure"
        case .dontCare, nil: return nil
        }
    }

    /// What the plan *does*, in Pillie's voice: warm and plain-spoken, like a friend
    /// walking the journey with you. Personalized to the answers the user gave (their
    /// Due Action Time, the risk window they described, and how missing feels), while
    /// staying free of fake stats, specific app names (no trademark snags), em dashes,
    /// and mechanism claims the app doesn't honor.
    var strategyPoints: [String] {
        [
            PillieLocalization.string("onboarding.plan.subtitle", locale: locale),
            PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale),
            PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
        ]
    }

    /// The concrete "what happens" when it's time. Generic about which apps (never
    /// naming a brand), warm, method-aware, and short (two lines max).
    private var lockStrategyPoint: String {
        "At \(dueActionTimeText), your distracting apps lock tight till you \(language.actionPhrase)."
    }

    /// Speaks back to the risk window the user told us about, like Pillie listened.
    private var riskStrategyPoint: String {
        switch riskWindow {
        case .rightAfterAlarm: return "You're quick on the snooze, so Pillie jumps in the second it rings."
        case .withinFiveMinutes: return "Those first few minutes are slippery, so Pillie's got them covered."
        case .laterInDay: return "Your slips sneak in later, so Pillie keeps watch till you check in."
        case .randomly: return "Slips can strike anytime, so Pillie stays on guard all day."
        case nil: return "Pillie holds the line till you check in. No quiet skips."
        }
    }

    /// The warm payoff, speaking to how missing feels (or how often it happens).
    private var reassuranceStrategyPoint: String {
        switch delayConsequence {
        case .stressful: return "No more frantic scramble. One tap and you can breathe easy."
        case .annoying: return "No more nagging guilt. Done once, off your mind."
        case .scary: return "Pure peace of mind. You'll always know it's handled."
        case .overthink: return "No more replaying it in your head. Pillie remembers for you."
        case .doubleCheck: return "One record you can trust, so you never double-check again."
        case .dontCare, .none:
            switch missFrequency {
            case .often, .almostDaily: return "We'll catch the slips before they pile up. Gently."
            case .rarely, .sometimes, .none: return "Friendly nudges that slip right into your day."
            }
        }
    }

    /// Honest framing: this is an editable draft, not a committed configuration.
    var disclaimer: String {
        PillieLocalization.string("onboarding.plan.disclaimer", locale: locale)
    }

    /// Every user-visible string, for safe-copy assertions and accessibility.
    var visibleCopy: [String] {
        [headline, leadLine, mainRiskValue, windowValue, protectionModeValue, protectedAppsLabel, lockMechanismSummary, disclaimer]
            + detectedSignals + strategyPoints
    }
}

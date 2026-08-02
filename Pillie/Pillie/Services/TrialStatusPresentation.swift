//
//  TrialStatusPresentation.swift
//  Pillie
//
//  Drives the truthful in-trial protection-status indicator and its status
//  sheet (issues #166/#220 / ADR 0007). Pure presentation logic (no SwiftUI) so the
//  visibility and day-count contract is testable as a value type: visible only
//  during an active Reverse Trial without an entitlement, with day copy that
//  agrees with the midnight-after-day-14 expiry rule ("ends tonight" on the
//  last protected day, never a misleading "0 days left").
//

import Foundation

struct TrialStatusPresentation: Equatable {
    /// Local-day rollovers until expiry (`ReverseTrialClock.daysRemaining`).
    let daysRemaining: Int
    let protectionActive: Bool
    let trialEndDate: Date?
    let locale: Locale
    let trialEndTerms: TrialEndAccessTerms

    init(
        daysRemaining: Int,
        protectionActive: Bool = false,
        trialEndDate: Date? = nil,
        locale: Locale = .current,
        trialEndTerms: TrialEndAccessTerms = .legacy
    ) {
        self.daysRemaining = daysRemaining
        self.protectionActive = protectionActive
        self.trialEndDate = trialEndDate
        self.locale = locale
        self.trialEndTerms = trialEndTerms
    }

    /// Day count as shown to the user: the trial promises "14 days free", so
    /// the partial grant day (15 rollovers left) never reads above the promise.
    var displayedDaysRemaining: Int {
        min(daysRemaining, ReverseTrialClock.fullDays)
    }

    /// Whether the trial expires at tonight's local-day rollover — the whole
    /// last day is still protected, so copy says "ends tonight", never "0 days
    /// left" (misleading while active) or "1 days left".
    var endsTonight: Bool {
        daysRemaining == 1
    }

    /// The persistent indicator distinguishes active protection from setup
    /// still being needed while preserving the trial countdown.
    var indicatorLabel: String {
        if trialEndTerms == .hardPaywall
            || ["de", "it"].contains(locale.language.languageCode?.identifier ?? "") {
            let key = switch (protectionActive, endsTonight) {
            case (true, true): "trial.status.indicator.active_tonight"
            case (true, false): "trial.status.indicator.active"
            case (false, true): "trial.status.indicator.setup_tonight"
            case (false, false): "trial.status.indicator.setup"
            }
            if endsTonight {
                return PillieLocalization.string(key, table: "Commerce", locale: locale)
            }
            return PillieLocalization.formatted(
                key,
                table: "Commerce",
                locale: locale,
                arguments: Int64(displayedDaysRemaining)
            )
        }
        if protectionActive {
            return endsTonight
                ? "Protection active · ends tonight"
                : "Protection active · \(displayedDaysRemaining) days left"
        }
        return endsTonight
            ? "Set up protection · ends tonight"
            : "Set up protection · \(displayedDaysRemaining) days left"
    }

    /// Copy for the trial status sheet behind the indicator.
    var sheetContent: TrialStatusSheetContent {
        sheetContent(for: .unconfigured)
    }

    func sheetContent(for activationState: TrialActivationState) -> TrialStatusSheetContent {
        if trialEndTerms == .hardPaywall
            || ["de", "it"].contains(locale.language.languageCode?.identifier ?? "") {
            let title = trialEndDate.map {
                CommercePresentation.trialEndText(date: $0, locale: locale)
            } ?? PillieLocalization.string(
                "trial.status.title",
                table: "Commerce",
                locale: locale
            )
            return TrialStatusSheetContent(
                title: title,
                expiryRows: [
                    TrialExpiryRow(
                        text: PillieLocalization.string(
                        trialEndTerms == .hardPaywall
                            ? "trial.status.after.plus_pauses"
                            : "trial.status.after.blocking_off",
                        table: "Commerce",
                        locale: locale
                        ),
                        symbol: trialEndTerms == .hardPaywall ? "lock.fill" : "nosign"
                    ),
                    TrialExpiryRow(
                        text: PillieLocalization.string(
                        trialEndTerms == .hardPaywall
                            ? "trial.status.after.plan_required"
                            : "trial.status.after.reminders_free",
                        table: "Commerce",
                        locale: locale
                        ),
                        symbol: trialEndTerms == .hardPaywall ? "creditcard.fill" : "bell.fill"
                    ),
                    TrialExpiryRow(
                        text: PillieLocalization.string(
                            "trial.status.after.setup_saved",
                            table: "Commerce",
                            locale: locale
                        ),
                        symbol: "checkmark.circle.fill"
                    ),
                ],
                ctaTitle: PillieLocalization.string(
                    "trial.status.keep_plus",
                    table: "Commerce",
                    locale: locale
                ),
                activationItems: TrialActivationItem.make(
                    for: activationState,
                    locale: locale
                )
            )
        }
        return TrialStatusSheetContent(
            title: endsTonight
                ? "Your Plus trial ends tonight"
                : "\(displayedDaysRemaining) days left in your Plus trial",
            expiryRows: [
                TrialExpiryRow(text: "App blocking turns off", symbol: "nosign"),
                TrialExpiryRow(text: "Reminders stay free, forever", symbol: "bell.fill"),
                TrialExpiryRow(
                    text: "Your blocker setup is saved",
                    symbol: "checkmark.circle.fill"
                ),
            ],
            ctaTitle: "Keep Pillie Plus",
            activationItems: TrialActivationItem.make(for: activationState, locale: locale)
        )
    }

    /// The indicator + sheet surface, or `nil` when no indicator should exist:
    /// entitled users (including mid-trial purchases), expired trials, or no
    /// trial ever granted.
    static func make(
        state: PlusAccessState,
        protectionActive: Bool = false,
        calendar: Calendar,
        now: Date,
        locale: Locale = .current,
        hardPaywallEnabled: Bool = false,
        termsCohort: TrialTermsCohort? = nil
    ) -> TrialStatusPresentation? {
        // Entitlement wins over a still-running trial clock: a mid-trial
        // purchase removes the indicator immediately.
        guard !state.hasEntitlement, let grantDate = state.trialGrantDate else { return nil }
        let clock = ReverseTrialClock(grantDate: grantDate)
        guard clock.isActive(calendar: calendar, now: now) else { return nil }
        let assignedTermsCohort = termsCohort
            ?? HardPaywallPolicy.cohort(forTrialGrantedAt: grantDate)
        return TrialStatusPresentation(
            daysRemaining: clock.daysRemaining(calendar: calendar, now: now),
            protectionActive: protectionActive,
            trialEndDate: clock.expiryMoment(calendar: calendar),
            locale: locale,
            trialEndTerms: HardPaywallPolicy.terms(
                for: assignedTermsCohort,
                hardPaywallEnabled: hardPaywallEnabled
            )
        )
    }
}

/// Copy for the trial status sheet: remaining time, what's unlocked, what
/// expiry changes, and the quiet "Keep Plus" path into the existing purchase
/// flow — the only in-trial purchase surface besides the Settings row.
struct TrialStatusSheetContent: Equatable {
    let title: String
    let expiryRows: [TrialExpiryRow]
    let ctaTitle: String
    let activationItems: [TrialActivationItem]
}

struct TrialExpiryRow: Equatable {
    let text: String
    let symbol: String
}

struct TrialActivationState: Equatable {
    let appBlockingActive: Bool
    let customMessagesCustomized: Bool
    let smartRemindersCustomized: Bool

    static let unconfigured = TrialActivationState(
        appBlockingActive: false,
        customMessagesCustomized: false,
        smartRemindersCustomized: false
    )
}

enum TrialActivationAction: Equatable {
    case appBlocking
    case customMessages
    case smartReminders
}

struct TrialActivationItem: Equatable {
    let feature: AnalyticsTrialStatusFeature
    let title: String
    let status: AnalyticsTrialActivationStatus
    let action: TrialActivationAction?
    let isRecommended: Bool
    var locale: Locale = .current

    var statusTitle: String {
        if ["de", "it"].contains(locale.language.languageCode?.identifier ?? "") {
            let key = switch status {
            case .setUp: "trial.activation.status.setup"
            case .active: "trial.activation.status.active"
            case .activeAutomatically: "trial.activation.status.active_automatically"
            case .personalize: "trial.activation.status.personalize"
            case .customized: "trial.activation.status.customized"
            case .on: "trial.activation.status.on"
            }
            return PillieLocalization.string(key, table: "Commerce", locale: locale)
        }
        return switch status {
        case .setUp: "Set up"
        case .active: "Active"
        case .activeAutomatically: "Active automatically"
        case .personalize: "Personalize"
        case .customized: "Customized"
        case .on: "On"
        }
    }

    var actionTitle: String? {
        if ["de", "it"].contains(locale.language.languageCode?.identifier ?? "") {
            let key: String? = switch action {
            case .appBlocking:
                status == .active
                    ? "trial.activation.action.manage"
                    : "trial.activation.action.setup"
            case .customMessages:
                status == .customized
                    ? "trial.activation.action.edit"
                    : "trial.activation.action.personalize"
            case .smartReminders:
                "trial.activation.action.customize"
            case nil:
                nil
            }
            return key.map {
                PillieLocalization.string($0, table: "Commerce", locale: locale)
            }
        }
        return switch action {
        case .appBlocking: status == .active ? "Manage" : "Set up"
        case .customMessages: status == .customized ? "Edit" : "Personalize"
        case .smartReminders: "Customize"
        case nil: nil
        }
    }

    var symbolName: String {
        switch feature {
        case .appBlocking: "nosign"
        case .shakeToConfirm: "iphone.radiowaves.left.and.right"
        case .smartReminders: "bell.fill"
        case .customMessages: "text.bubble.fill"
        }
    }

    static func make(
        for state: TrialActivationState,
        locale: Locale = .current
    ) -> [TrialActivationItem] {
        let recommendation: TrialActivationAction? = if !state.appBlockingActive {
            .appBlocking
        } else if !state.customMessagesCustomized {
            .customMessages
        } else if !state.smartRemindersCustomized {
            .smartReminders
        } else {
            // All setup is complete. Smart Reminders remains the useful,
            // adjustable control, so the hub still has exactly one next action.
            .smartReminders
        }

        let localizedLanguage = ["de", "it"].contains(
            locale.language.languageCode?.identifier ?? ""
        )
        func title(_ key: String, fallback: String) -> String {
            localizedLanguage
                ? PillieLocalization.string(key, table: "Commerce", locale: locale)
                : fallback
        }
        return [
            TrialActivationItem(
                feature: .appBlocking,
                title: title("paywall.feature.app_blocking.compact", fallback: "App blocking"),
                status: state.appBlockingActive ? .active : .setUp,
                action: .appBlocking,
                isRecommended: recommendation == .appBlocking,
                locale: locale
            ),
            TrialActivationItem(
                feature: .smartReminders,
                title: title("paywall.feature.smart_reminders", fallback: "Smart Reminders"),
                status: state.smartRemindersCustomized ? .customized : .activeAutomatically,
                action: .smartReminders,
                isRecommended: recommendation == .smartReminders,
                locale: locale
            ),
            TrialActivationItem(
                feature: .customMessages,
                title: title("paywall.feature.custom_messages.compact", fallback: "Custom messages"),
                status: state.customMessagesCustomized ? .customized : .personalize,
                action: .customMessages,
                isRecommended: recommendation == .customMessages,
                locale: locale
            ),
            TrialActivationItem(
                feature: .shakeToConfirm,
                title: title("paywall.feature.shake", fallback: "Shake to confirm"),
                status: .on,
                action: nil,
                isRecommended: false,
                locale: locale
            ),
        ]
    }
}

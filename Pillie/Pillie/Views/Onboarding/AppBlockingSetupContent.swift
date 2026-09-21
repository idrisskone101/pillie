import Foundation

struct AppBlockingSetupContent {
    let titleLead: String
    let subtitle: String

    let emptyTitle: String
    let emptyUnlockFormat: String
    let emptyMarkTaken: String
    let emptyDetail: String
    let chooseAppsCTA: String

    let authorizationDeniedTitle: String
    let authorizationDeniedDetail: String
    let retryAuthorizationCTA: String

    let selectedSummaryLabel: String
    let selectedPrivacyNote: String
    let changeSelectionCTA: String

    let privacyNote: String
    let finishCTA: String
    let skipCTA: String

    let lockedTitle: String
    let lockedSubtitle: String
    let lockedDetail: String
    let lockedCTA: String

    var visibleCopy: [String] {
        [
            titleLead, subtitle,
            emptyTitle, emptyUnlockFormat, emptyMarkTaken, emptyDetail,
            authorizationDeniedTitle, authorizationDeniedDetail, retryAuthorizationCTA,
            chooseAppsCTA, selectedSummaryLabel, selectedPrivacyNote, changeSelectionCTA,
            privacyNote, finishCTA, skipCTA, lockedTitle, lockedSubtitle, lockedDetail, lockedCTA
        ]
    }

    func emptyStateAccessibilityLabel(unlockHint: String) -> String {
        "\(emptyTitle). \(unlockHint)"
    }

    var lockedAccessibilityLabel: String {
        let separator = lockedTitle.last.map { ".!?…".contains($0) } == true ? " " : ". "
        return "\(lockedTitle)\(separator)\(lockedDetail)"
    }

    static var `default`: AppBlockingSetupContent { localized() }

    static func localized(
        locale: Locale = .current,
        trialEndTerms: TrialEndAccessTerms = .legacy
    ) -> AppBlockingSetupContent {
        AppBlockingSetupContent(
            titleLead: PillieLocalization.string("onboarding.blocking_setup.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale),
            emptyTitle: PillieLocalization.string("onboarding.blocking_setup.paused_app", locale: locale),
            emptyUnlockFormat: PillieLocalization.string("onboarding.blocking_setup.unlock_hint", locale: locale),
            emptyMarkTaken: PillieLocalization.string("onboarding.blocking_setup.mark_taken", locale: locale),
            emptyDetail: PillieLocalization.string(
                "onboarding.blocking_setup.empty_detail",
                locale: locale
            ),
            chooseAppsCTA: PillieLocalization.string("onboarding.blocking_setup.allow_pausing", locale: locale),
            authorizationDeniedTitle: PillieLocalization.string("error.screen_time.title", locale: locale),
            authorizationDeniedDetail: PillieLocalization.string("error.screen_time.body", locale: locale),
            retryAuthorizationCTA: PillieLocalization.string("global.action.retry", locale: locale),
            selectedSummaryLabel: PillieLocalization.string(
                "onboarding.blocking_setup.selected_summary",
                locale: locale
            ),
            selectedPrivacyNote: PillieLocalization.string(
                "onboarding.blocking_setup.privacy",
                locale: locale
            ),
            changeSelectionCTA: PillieLocalization.string("global.action.edit", locale: locale),
            privacyNote: PillieLocalization.string("onboarding.blocking_setup.privacy", locale: locale),
            finishCTA: PillieLocalization.string("global.action.continue", locale: locale),
            skipCTA: PillieLocalization.string("onboarding.blocking_setup.skip", locale: locale),
            lockedTitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
            lockedSubtitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
            lockedDetail: PillieLocalization.string(
                trialEndTerms == .hardPaywall
                    ? "onboarding.blocking_setup.hard_paywall_locked_detail"
                    : "onboarding.demo.free_body",
                table: "Commerce",
                locale: locale
            ),
            lockedCTA: PillieLocalization.string(
                trialEndTerms == .hardPaywall
                    ? "paywall.action.upgrade"
                    : "global.action.continue",
                table: trialEndTerms == .hardPaywall ? "Commerce" : nil,
                locale: locale
            )
        )
    }

    static func formattedEmptyUnlock(
        format: String,
        reminderHour: Int,
        reminderMinute: Int,
        locale: Locale = .current
    ) -> String {
        let twelve = ReminderTimeConverter.toTwelveHour(hour24: reminderHour, minute: reminderMinute)
        let time = ProtectionPlanRoutineSummary.clockText(
            hour12: twelve.hour,
            minute: twelve.minute,
            isPM: twelve.period == 1,
            locale: locale
        )
        return String(format: format, locale: locale, arguments: [time as CVarArg])
    }
}

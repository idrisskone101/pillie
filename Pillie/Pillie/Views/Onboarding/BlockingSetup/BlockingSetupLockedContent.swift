//
//  BlockingSetupLockedContent.swift
//  Pillie
//

import Foundation

struct BlockingSetupLockedContent: Equatable {
    let title: String
    let subtitle: String
    let cardTitle: String
    let detail: String
    let cta: String

    var accessibilityLabel: String {
        let separator = cardTitle.last.map { ".!?…".contains($0) } == true ? " " : ". "
        return "\(cardTitle)\(separator)\(detail)"
    }

    static func localized(
        locale: Locale = PillieLocalization.appLocale,
        trialEndTerms: TrialEndAccessTerms = .legacy
    ) -> BlockingSetupLockedContent {
        BlockingSetupLockedContent(
            title: PillieLocalization.string("onboarding.blocking_setup.title", locale: locale),
            subtitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
            cardTitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
            detail: PillieLocalization.string(
                trialEndTerms == .hardPaywall
                    ? "onboarding.blocking_setup.hard_paywall_locked_detail"
                    : "onboarding.demo.free_body",
                table: "Commerce",
                locale: locale
            ),
            cta: PillieLocalization.string(
                trialEndTerms == .hardPaywall
                    ? "paywall.action.upgrade"
                    : "global.action.continue",
                table: trialEndTerms == .hardPaywall ? "Commerce" : nil,
                locale: locale
            )
        )
    }
}

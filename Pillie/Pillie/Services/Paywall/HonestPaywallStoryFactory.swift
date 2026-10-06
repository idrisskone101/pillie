//
//  HonestPaywallStoryFactory.swift
//  Pillie
//

import Foundation

enum HonestPaywallStoryFactory {
    static func duringTrial(
        daysRemaining: Int,
        endsTonight: Bool,
        locale: Locale
    ) -> HonestPaywallStory {
        HonestPaywallStory(
            title: commerce("paywall.board.during_trial.title", locale),
            subtitle: endsTonight
                ? commerce("paywall.board.during_trial.subtitle.tonight", locale)
                : PillieLocalization.formatted(
                    "paywall.board.during_trial.subtitle",
                    table: "Commerce",
                    locale: locale,
                    arguments: Int64(ReverseTrialClock.displayedDaysRemaining(daysRemaining))
                ),
            review: review("paywall.review.trial", locale)
        )
    }

    static func trialEnded(
        terms: TrialEndAccessTerms,
        method: ContraceptiveMethod,
        locale: Locale
    ) -> HonestPaywallStory {
        switch terms {
        case .hardPaywall:
            HonestPaywallStory(
                title: commerce("paywall.board.trial_ended.title", locale),
                subtitle: commerce("paywall.board.trial_ended.subtitle.\(method.rawValue)", locale),
                review: review("paywall.review.support", locale)
            )
        case .legacy:
            // Grandfathered users keep free daily reminders, so "get your
            // reminders back" would be false for them.
            settingsFree(method: method, locale: locale)
        }
    }

    static func settingsFree(
        method: ContraceptiveMethod,
        locale: Locale
    ) -> HonestPaywallStory {
        HonestPaywallStory(
            title: commerce("paywall.board.get_plus.title.\(method.rawValue)", locale),
            subtitle: commerce("paywall.board.get_plus.subtitle", locale),
            review: review("paywall.review.blocking", locale)
        )
    }

    private static func review(_ quoteKey: String, _ locale: Locale) -> PaywallReview {
        PaywallReview(
            quote: commerce(quoteKey, locale),
            source: commerce("paywall.review.source", locale)
        )
    }

    private static func commerce(_ key: String, _ locale: Locale) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }
}

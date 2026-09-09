//
//  HonestPaywallStoryFactory.swift
//  Pillie
//

import Foundation

enum HonestPaywallStoryFactory {
    static func duringTrial(
        daysRemaining: Int,
        locale: Locale
    ) -> HonestPaywallTrialActiveStory {
        HonestPaywallTrialActiveStory(
            title: PillieLocalization.string(
                "paywall.story.trial_active.title",
                table: "Commerce",
                locale: locale
            ),
            subtitle: PillieLocalization.string(
                "paywall.story.trial_active.subtitle",
                table: "Commerce",
                locale: locale
            ),
            daysRemaining: daysRemaining,
            daysStampText: PillieLocalization.string(
                "paywall.story.trial_active.stamp",
                table: "Commerce",
                locale: locale
            ),
            benefitChips: [
                PaywallBenefitChip(
                    label: PillieLocalization.string(
                        "paywall.story.trial_active.chip.reminders",
                        table: "Commerce",
                        locale: locale
                    ),
                    tint: .lavender
                ),
                PaywallBenefitChip(
                    label: PillieLocalization.string(
                        "paywall.story.trial_active.chip.blocking",
                        table: "Commerce",
                        locale: locale
                    ),
                    tint: .sage
                ),
                PaywallBenefitChip(
                    label: PillieLocalization.string(
                        "paywall.story.trial_active.chip.history",
                        table: "Commerce",
                        locale: locale
                    ),
                    tint: .coralSoft
                ),
            ]
        )
    }

    static func trialEnded(
        stats: TrialEndOwnStats,
        terms: TrialEndAccessTerms,
        locale: Locale
    ) -> HonestPaywallTrialEndedStory {
        if let body = ownRecordBody(stats: stats, locale: locale) {
            return HonestPaywallTrialEndedStory(
                title: PillieLocalization.string(
                    "paywall.story.trial_ended.title",
                    table: "Commerce",
                    locale: locale
                ),
                subtitle: PillieLocalization.string(
                    "paywall.story.trial_ended.subtitle",
                    table: "Commerce",
                    locale: locale
                ),
                body: body,
                chrome: chrome(for: terms)
            )
        }

        switch terms {
        case .legacy:
            let settings = settingsFree(locale: locale)
            return HonestPaywallTrialEndedStory(
                title: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.legacy.title",
                    table: "Commerce",
                    locale: locale
                ),
                subtitle: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.legacy.subtitle",
                    table: "Commerce",
                    locale: locale
                ),
                body: .comparison(free: settings.freeCard, plus: settings.plusCard),
                chrome: chrome(for: .legacy)
            )
        case .hardPaywall:
            return HonestPaywallTrialEndedStory(
                title: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.hard.title",
                    table: "Commerce",
                    locale: locale
                ),
                subtitle: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.hard.subtitle",
                    table: "Commerce",
                    locale: locale
                ),
                body: .chips(
                    returningHardChips(locale: locale),
                    aside: PillieLocalization.string(
                        "paywall.story.trial_ended.returning.hard.aside",
                        table: "Commerce",
                        locale: locale
                    )
                ),
                chrome: chrome(for: .hardPaywall)
            )
        }
    }

    static func settingsFree(locale: Locale) -> HonestPaywallSettingsStory {
        HonestPaywallSettingsStory(
            title: PillieLocalization.string(
                "paywall.story.settings_free.title",
                table: "Commerce",
                locale: locale
            ),
            subtitle: PillieLocalization.string(
                "paywall.story.settings_free.subtitle",
                table: "Commerce",
                locale: locale
            ),
            freeCard: PaywallComparisonCard(
                tierLabel: PillieLocalization.string(
                    "global.status.free",
                    locale: locale
                ),
                bullets: [
                    PillieLocalization.string(
                        "paywall.feature.daily_reminders",
                        table: "Commerce",
                        locale: locale
                    ),
                ],
                background: .lavender
            ),
            plusCard: PaywallComparisonCard(
                tierLabel: PillieLocalization.string(
                    "paywall.story.settings_free.plus_label",
                    table: "Commerce",
                    locale: locale
                ),
                bullets: [
                    PillieLocalization.string(
                        "paywall.feature.daily_reminders",
                        table: "Commerce",
                        locale: locale
                    ),
                    PillieLocalization.string(
                        "paywall.feature.smart_reminders",
                        table: "Commerce",
                        locale: locale
                    ),
                    PillieLocalization.string(
                        "paywall.feature.app_blocking.compact",
                        table: "Commerce",
                        locale: locale
                    ),
                ],
                background: .coralSoft
            )
        )
    }

    private static func chrome(for terms: TrialEndAccessTerms) -> HonestPaywallChrome {
        switch terms {
        case .hardPaywall:
            HonestPaywallChrome(
                showsClose: false,
                allowsInteractiveDismiss: false,
                showsContinueFree: false
            )
        case .legacy:
            HonestPaywallChrome(
                showsClose: true,
                allowsInteractiveDismiss: true,
                showsContinueFree: true
            )
        }
    }

    private static func ownRecordBody(
        stats: TrialEndOwnStats,
        locale: Locale
    ) -> HonestPaywallTrialEndedBody? {
        let doseTile = statTile(
            value: stats.dosesTaken,
            labelKey: "paywall.story.trial_ended.tile.doses",
            background: .coralSoft,
            locale: locale
        )
        let streakTile = statTile(
            value: stats.currentStreak,
            labelKey: "paywall.story.trial_ended.tile.streak",
            background: .ink,
            locale: locale
        )
        guard doseTile != nil || streakTile != nil else { return nil }

        let lossCount = [stats.dosesTaken, stats.currentStreak, stats.blocksIntercepted]
            .compactMap { $0 }
            .first { $0 > 0 }
        let lossLine = lossCount.map { count in
            PillieLocalization.formatted(
                "paywall.story.trial_ended.aside",
                table: "Commerce",
                locale: locale,
                arguments: Int64(count)
            )
        } ?? ""

        return .stats(dose: doseTile, streak: streakTile, lossLine: lossLine)
    }

    private static func returningHardChips(locale: Locale) -> [PaywallBenefitChip] {
        [
            PaywallBenefitChip(
                label: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.hard.chip.blocking",
                    table: "Commerce",
                    locale: locale
                ),
                tint: .sage
            ),
            PaywallBenefitChip(
                label: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.hard.chip.reminders",
                    table: "Commerce",
                    locale: locale
                ),
                tint: .lavender
            ),
            PaywallBenefitChip(
                label: PillieLocalization.string(
                    "paywall.story.trial_ended.returning.hard.chip.history",
                    table: "Commerce",
                    locale: locale
                ),
                tint: .coralSoft
            ),
        ]
    }

    private static func statTile(
        value: Int?,
        labelKey: String,
        background: PaywallTileBackground,
        locale: Locale
    ) -> PaywallStatTile? {
        guard let value, value > 0 else { return nil }
        return PaywallStatTile(
            label: PillieLocalization.string(labelKey, table: "Commerce", locale: locale),
            value: "\(value)",
            background: background
        )
    }
}

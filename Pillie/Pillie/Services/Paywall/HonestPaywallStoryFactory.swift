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
        let doseTile = Self.statTile(
            value: stats.dosesTaken,
            labelKey: "paywall.story.trial_ended.tile.doses",
            background: .coralSoft,
            locale: locale
        )
        let streakTile = Self.statTile(
            value: stats.currentStreak,
            labelKey: "paywall.story.trial_ended.tile.streak",
            background: .ink,
            locale: locale
        )
        let hasOwnRecord = doseTile != nil || streakTile != nil

        let lossCount = [stats.dosesTaken, stats.currentStreak, stats.blocksIntercepted]
            .compactMap { $0 }
            .first { $0 > 0 }

        let hardChrome = HonestPaywallChrome(
            showsClose: false,
            allowsInteractiveDismiss: false,
            showsContinueFree: false
        )
        let legacyChrome = HonestPaywallChrome(
            showsClose: true,
            allowsInteractiveDismiss: true,
            showsContinueFree: true
        )

        if hasOwnRecord {
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
                doseTile: doseTile,
                streakTile: streakTile,
                fallback: nil,
                handwrittenLossLine: lossCount.map { count in
                    PillieLocalization.formatted(
                        "paywall.story.trial_ended.aside",
                        table: "Commerce",
                        locale: locale,
                        arguments: Int64(count)
                    )
                } ?? "",
                chrome: terms == .hardPaywall ? hardChrome : legacyChrome
            )
        }

        if terms == .legacy {
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
                doseTile: nil,
                streakTile: nil,
                fallback: .comparison(free: settings.freeCard, plus: settings.plusCard),
                handwrittenLossLine: "",
                chrome: legacyChrome
            )
        }

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
            doseTile: nil,
            streakTile: nil,
            fallback: .chips([
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
                        "paywall.story.trial_active.chip.history",
                        table: "Commerce",
                        locale: locale
                    ),
                    tint: .coralSoft
                ),
            ]),
            handwrittenLossLine: PillieLocalization.string(
                "paywall.story.trial_ended.returning.hard.aside",
                table: "Commerce",
                locale: locale
            ),
            chrome: hardChrome
        )
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

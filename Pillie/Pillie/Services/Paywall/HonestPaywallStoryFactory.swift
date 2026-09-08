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
        let doseValue = stats.dosesTaken.map { taken in
            if let due = stats.dosesDue, due > 0 {
                return "\(taken)/\(due)"
            }
            return "\(taken)"
        } ?? "-"

        let streakValue = stats.currentStreak.map { "\($0)" } ?? "-"

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
            doseTile: PaywallStatTile(
                label: PillieLocalization.string(
                    "paywall.story.trial_ended.tile.doses",
                    table: "Commerce",
                    locale: locale
                ),
                value: doseValue,
                background: .coralSoft
            ),
            streakTile: PaywallStatTile(
                label: PillieLocalization.string(
                    "paywall.story.trial_ended.tile.streak",
                    table: "Commerce",
                    locale: locale
                ),
                value: streakValue,
                background: .ink
            ),
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
}

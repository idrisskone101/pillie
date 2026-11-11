//
//  ClassicPaywallStoryFactory.swift
//  Pillie
//
//  Ported from HonestPaywallStoryFactory at 2c8062a. Keys that changed since
//  then live under `paywall.classic.`.
//

import Foundation

enum ClassicPaywallStoryFactory {
    static func duringTrial(
        displayedDaysRemaining: Int,
        locale: Locale
    ) -> ClassicPaywallTrialActiveStory {
        ClassicPaywallTrialActiveStory(
            title: commerce("paywall.classic.paywall.story.trial_active.title", locale),
            subtitle: commerce("paywall.classic.paywall.story.trial_active.subtitle", locale),
            daysRemaining: displayedDaysRemaining,
            daysStampText: commerce("paywall.story.trial_active.stamp", locale),
            benefitChips: [
                ClassicPaywallBenefitChip(
                    label: commerce("paywall.classic.paywall.story.trial_active.chip.reminders", locale),
                    tint: .lavender
                ),
                ClassicPaywallBenefitChip(
                    label: commerce("paywall.classic.paywall.story.trial_active.chip.blocking", locale),
                    tint: .sage
                ),
                ClassicPaywallBenefitChip(
                    label: commerce("paywall.classic.paywall.story.trial_active.chip.history", locale),
                    tint: .coralSoft
                ),
            ]
        )
    }

    static func trialEnded(
        stats: TrialEndOwnStats,
        terms: TrialEndAccessTerms,
        locale: Locale
    ) -> ClassicPaywallTrialEndedStory {
        if let body = ownRecordBody(stats: stats, locale: locale) {
            return ClassicPaywallTrialEndedStory(
                title: commerce("paywall.classic.paywall.story.trial_ended.title", locale),
                subtitle: commerce(
                    terms == .hardPaywall
                        ? "paywall.classic.paywall.story.trial_ended.returning.hard.subtitle"
                        : "paywall.classic.paywall.story.trial_ended.subtitle",
                    locale
                ),
                body: body
            )
        }

        switch terms {
        case .legacy:
            let settings = settingsFree(locale: locale)
            return ClassicPaywallTrialEndedStory(
                title: commerce("paywall.classic.paywall.story.trial_ended.returning.legacy.title", locale),
                subtitle: commerce("paywall.classic.paywall.story.trial_ended.returning.legacy.subtitle", locale),
                body: .comparison(free: settings.freeCard, plus: settings.plusCard)
            )
        case .hardPaywall:
            return ClassicPaywallTrialEndedStory(
                title: commerce("paywall.classic.paywall.story.trial_ended.returning.hard.title", locale),
                subtitle: commerce("paywall.classic.paywall.story.trial_ended.returning.hard.subtitle", locale),
                body: .chips(
                    returningHardChips(locale: locale),
                    aside: commerce("paywall.classic.paywall.story.trial_ended.returning.hard.aside", locale)
                )
            )
        }
    }

    static func settingsFree(locale: Locale) -> ClassicPaywallSettingsStory {
        ClassicPaywallSettingsStory(
            title: commerce("paywall.classic.paywall.story.settings_free.title", locale),
            subtitle: commerce("paywall.classic.paywall.story.settings_free.subtitle", locale),
            freeCard: ClassicPaywallComparisonCard(
                tierLabel: PillieLocalization.string("global.status.free", locale: locale),
                bullets: [
                    commerce("paywall.feature.daily_reminders", locale),
                ],
                background: .lavender
            ),
            plusCard: ClassicPaywallComparisonCard(
                tierLabel: commerce("paywall.classic.paywall.story.settings_free.plus_label", locale),
                bullets: [
                    commerce("paywall.feature.daily_reminders", locale),
                    commerce("paywall.feature.smart_reminders", locale),
                    commerce("paywall.feature.app_blocking.compact", locale),
                ],
                background: .coralSoft
            )
        )
    }

    private static func ownRecordBody(
        stats: TrialEndOwnStats,
        locale: Locale
    ) -> ClassicPaywallTrialEndedBody? {
        let doseTile = statTile(
            value: stats.dosesTaken,
            labelKey: "paywall.classic.paywall.story.trial_ended.tile.doses",
            background: .coralSoft,
            locale: locale
        )
        let streakTile = statTile(
            value: stats.currentStreak,
            labelKey: "paywall.classic.paywall.story.trial_ended.tile.streak",
            background: .ink,
            locale: locale
        )
        guard doseTile != nil || streakTile != nil else { return nil }

        let lossCount = [stats.dosesTaken, stats.currentStreak, stats.blocksIntercepted]
            .compactMap { $0 }
            .first { $0 > 0 }
        let lossLine = lossCount.map { count in
            PillieLocalization.formatted(
                "paywall.classic.paywall.story.trial_ended.aside",
                table: "Commerce",
                locale: locale,
                arguments: Int64(count)
            )
        } ?? ""

        return .stats(dose: doseTile, streak: streakTile, lossLine: lossLine)
    }

    private static func returningHardChips(locale: Locale) -> [ClassicPaywallBenefitChip] {
        [
            ClassicPaywallBenefitChip(
                label: commerce("paywall.classic.paywall.story.trial_ended.returning.hard.chip.blocking", locale),
                tint: .sage
            ),
            ClassicPaywallBenefitChip(
                label: commerce("paywall.classic.paywall.story.trial_ended.returning.hard.chip.reminders", locale),
                tint: .lavender
            ),
            ClassicPaywallBenefitChip(
                label: commerce("paywall.classic.paywall.story.trial_ended.returning.hard.chip.history", locale),
                tint: .coralSoft
            ),
        ]
    }

    private static func statTile(
        value: Int?,
        labelKey: String,
        background: ClassicPaywallTileBackground,
        locale: Locale
    ) -> ClassicPaywallStatTile? {
        guard let value, value > 0 else { return nil }
        return ClassicPaywallStatTile(
            label: commerce(labelKey, locale),
            value: "\(value)",
            background: background
        )
    }

    private static func commerce(_ key: String, _ locale: Locale) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }
}

//
//  SoftPaywallContent.swift
//  Pillie
//

import SwiftUI

struct SoftPaywallContent {
    struct ComparisonRow {
        let title: String
        let detail: String?
        let icon: String
        let iconBackground: Color
        let iconColor: Color
        let freeIncluded: Bool
        let plusIncluded: Bool

        init(
            title: String,
            detail: String? = nil,
            icon: String,
            iconBackground: Color,
            iconColor: Color,
            freeIncluded: Bool,
            plusIncluded: Bool
        ) {
            self.title = title
            self.detail = detail
            self.icon = icon
            self.iconBackground = iconBackground
            self.iconColor = iconColor
            self.freeIncluded = freeIncluded
            self.plusIncluded = plusIncluded
        }
    }

    let title: String
    let titleAccent: String
    let subtitle: String
    let comparisonLabel: String
    let freeColumnLabel: String
    let plusColumnLabel: String
    let rows: [ComparisonRow]
    let annualPlanLabel: String
    let monthlyPlanLabel: String
    let reassurances: [String]
    let monthlyReassurances: [String]
    let primaryCTA: String
    let monthlyCTA: String
    let freeCTA: String
    let restoreCTA: String

    var visibleCopy: [String] {
        [title, titleAccent, subtitle, comparisonLabel, freeColumnLabel, plusColumnLabel]
            + rows.map(\.title)
            + rows.compactMap(\.detail)
            + [annualPlanLabel, monthlyPlanLabel]
            + reassurances
            + monthlyReassurances
            + [primaryCTA, monthlyCTA, freeCTA, restoreCTA]
    }

    static let `default` = SoftPaywallContent(
        title: "Stay on Track with",
        titleAccent: "Pillie Plus",
        subtitle: "Blocks distracting apps right when your reminder is due, for the days a nudge isn't enough.",
        comparisonLabel: "What you get",
        freeColumnLabel: "Free",
        plusColumnLabel: "Plus",
        rows: [
            ComparisonRow(
                title: "Daily reminders",
                icon: "bell.fill",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: true,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Smart Reminders",
                icon: "bell.badge.fill",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Block distracting apps",
                icon: "nosign",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Shake to confirm",
                icon: "iphone.radiowaves.left.and.right",
                iconBackground: PillieTheme.sage,
                iconColor: PillieTheme.verifiedGreen,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Custom reminder messages",
                icon: "text.bubble.fill",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "New perks as they launch",
                icon: "sparkles",
                iconBackground: PillieTheme.coralLight,
                iconColor: PillieTheme.coral,
                freeIncluded: false,
                plusIncluded: true
            )
        ],
        annualPlanLabel: "Annual",
        monthlyPlanLabel: "Monthly",
        reassurances: ["Cancel anytime"],
        monthlyReassurances: ["Cancel anytime", "No commitment"],
        primaryCTA: "Unlock Pillie Plus",
        monthlyCTA: "Start Pillie Plus monthly",
        freeCTA: "Continue with free plan",
        restoreCTA: "Restore Purchases"
    )

    static func localized(locale: Locale = .current) -> SoftPaywallContent {
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: locale)
        }
        return SoftPaywallContent(
            title: commerce("paywall.title"),
            titleAccent: "",
            subtitle: commerce("paywall.subtitle"),
            comparisonLabel: "Pillie Plus",
            freeColumnLabel: PillieLocalization.string("global.status.free", locale: locale),
            plusColumnLabel: "Plus",
            rows: [
                ComparisonRow(
                    title: commerce("paywall.feature.daily_reminders"),
                    icon: "bell.fill",
                    iconBackground: PillieTheme.lavender,
                    iconColor: PillieTheme.dark,
                    freeIncluded: true,
                    plusIncluded: true
                ),
                ComparisonRow(
                    title: commerce("paywall.feature.smart_reminders"),
                    icon: "bell.badge.fill",
                    iconBackground: PillieTheme.lavender,
                    iconColor: PillieTheme.dark,
                    freeIncluded: false,
                    plusIncluded: true
                ),
                ComparisonRow(
                    title: commerce("paywall.feature.app_blocking.compact"),
                    icon: "nosign",
                    iconBackground: PillieTheme.lavender,
                    iconColor: PillieTheme.dark,
                    freeIncluded: false,
                    plusIncluded: true
                ),
                ComparisonRow(
                    title: commerce("paywall.feature.shake"),
                    icon: "iphone.radiowaves.left.and.right",
                    iconBackground: PillieTheme.sage,
                    iconColor: PillieTheme.verifiedGreen,
                    freeIncluded: false,
                    plusIncluded: true
                ),
                ComparisonRow(
                    title: commerce("paywall.feature.custom_messages.compact"),
                    icon: "text.bubble.fill",
                    iconBackground: PillieTheme.lavender,
                    iconColor: PillieTheme.dark,
                    freeIncluded: false,
                    plusIncluded: true
                ),
                ComparisonRow(
                    title: commerce("paywall.feature.future.compact"),
                    icon: "sparkles",
                    iconBackground: PillieTheme.coralLight,
                    iconColor: PillieTheme.coral,
                    freeIncluded: false,
                    plusIncluded: true
                ),
            ],
            annualPlanLabel: commerce("paywall.plan.annual"),
            monthlyPlanLabel: commerce("paywall.plan.monthly"),
            reassurances: [commerce("paywall.plan.cancel_anytime_short")],
            monthlyReassurances: [commerce("paywall.plan.cancel_anytime_short")],
            primaryCTA: commerce("paywall.action.upgrade"),
            monthlyCTA: commerce("paywall.action.upgrade"),
            freeCTA: PillieLocalization.string("global.action.not_now", locale: locale),
            restoreCTA: commerce("paywall.action.restore")
        )
    }
}

enum PremiumPaywallFreeExitPolicy {
    static func allowsContinueFree(
        isFromOnboarding: Bool,
        trialEndTerms: TrialEndAccessTerms
    ) -> Bool {
        !isFromOnboarding || trialEndTerms == .legacy
    }
}

enum PremiumPaywallComparisonPolicy {
    static func showsFreeColumn(trialEndTerms: TrialEndAccessTerms) -> Bool {
        trialEndTerms == .legacy
    }
}

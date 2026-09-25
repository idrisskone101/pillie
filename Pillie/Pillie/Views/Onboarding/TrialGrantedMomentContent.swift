import SwiftUI

/// Copy for the Trial Granted Moment. Entirely fixed — the screen personalizes
/// nothing. Kept as a value type so the App Review disclosure line and the
/// no-purchase-UI boundary are testable without driving the SwiftUI view.
struct TrialGrantedMomentContent {
    struct Perk {
        let title: String
        let symbolName: String
    }

    struct TimelineDay {
        let label: String
        let title: String
        let detail: String
        let symbolName: String
        let circleBackground: Color
        let symbolColor: Color
    }

    struct Today {
        let label: String
        let title: String
        let perks: [Perk]
    }

    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String
    let today: Today
    let laterDays: [TimelineDay]
    /// The App Review pre-trial disclosures as one plain line: trial duration,
    /// what turns off at expiry, and the post-trial price (ADR 0007).
    let disclosure: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [badge, title, titleAccent, subtitle, today.label, today.title]
            + today.perks.map(\.title)
            + laterDays.flatMap { [$0.label, $0.title, $0.detail] }
            + [disclosure, primaryCTA]
    }

    static var `default`: TrialGrantedMomentContent { localized() }

    static func localized(
        locale: Locale = .current,
        trialEndTerms: TrialEndAccessTerms = .legacy
    ) -> TrialGrantedMomentContent {
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: locale)
        }
        return TrialGrantedMomentContent(
            badge: commerce("trial.granted.badge"),
            title: commerce("trial.granted.headline"),
            titleAccent: commerce("trial.granted.headline_accent"),
            subtitle: commerce("trial.granted.subtitle"),
            today: Today(
                label: commerce("trial.timeline.today"),
                title: commerce("trial.timeline.today_title"),
                perks: [
                    Perk(title: commerce("paywall.feature.app_blocking"), symbolName: "nosign"),
                    Perk(
                        title: commerce("paywall.feature.shake"),
                        symbolName: "iphone.radiowaves.left.and.right"
                    ),
                    Perk(
                        title: commerce("paywall.feature.smart_reminders"),
                        symbolName: "bell.fill"
                    ),
                    Perk(
                        title: commerce("paywall.feature.custom_messages"),
                        symbolName: "text.bubble.fill"
                    ),
                ]
            ),
            laterDays: [
                TimelineDay(
                    label: commerce("trial.granted.warning.label"),
                    title: commerce("trial.granted.warning.title"),
                    detail: commerce("trial.granted.warning.detail"),
                    symbolName: "bell.fill",
                    circleBackground: PillieTheme.lavender,
                    symbolColor: PillieTheme.textPrimary
                ),
                TimelineDay(
                    label: commerce("trial.granted.choice.label"),
                    title: commerce("trial.granted.choice.title"),
                    detail: commerce(
                        trialEndTerms == .hardPaywall
                            ? "trial.granted.choice.detail.hard_paywall"
                            : "trial.granted.choice.detail"
                    ),
                    symbolName: "leaf.fill",
                    circleBackground: PillieTheme.sage,
                    symbolColor: PillieTheme.verifiedGreen
                ),
            ],
            disclosure: commerce(
                trialEndTerms == .hardPaywall
                    ? "trial.granted.disclosure.hard_paywall"
                    : "trial.granted.disclosure"
            ),
            primaryCTA: commerce("trial.granted.cta")
        )
    }
}

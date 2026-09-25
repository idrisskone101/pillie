import Foundation

/// Copy for the update announcement sheet. Entirely fixed — nothing is
/// personalized.
struct UpdateTrialAnnouncementContent {
    struct Perk {
        let title: String
        let symbolName: String
    }

    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String
    /// The same four Plus perks the Trial Granted Moment lists.
    let perks: [Perk]
    /// The App Review pre-trial disclosures as one plain line — identical to the
    /// Trial Granted Moment's so the two grant surfaces can never drift.
    let disclosure: String
    /// The primary action — deep-links into the Settings blocker editor so setup
    /// completed there activates blocking under the trial.
    let primaryCTA: String
    /// The dismiss action. Unlike the onboarding Trial Granted Moment, the sheet
    /// interrupts an existing user's session, so it must offer a way out.
    let dismissCTA: String

    var visibleCopy: [String] {
        [badge, title, titleAccent, subtitle]
            + perks.map(\.title)
            + [disclosure, primaryCTA, dismissCTA]
    }

    static let `default` = UpdateTrialAnnouncementContent(
        badge: "14 active days free · no card",
        title: "Pillie Plus is now",
        titleAccent: "free for you.",
        subtitle: "This update starts your full 14 active-day Plus trial. Everything unlocks now.",
        perks: [
            Perk(title: "App blocking", symbolName: "nosign"),
            Perk(title: "Shake to confirm", symbolName: "iphone.radiowaves.left.and.right"),
            Perk(title: "Smart Reminders", symbolName: "bell.fill"),
            Perk(title: "Custom messages", symbolName: "text.bubble.fill"),
        ],
        disclosure: TrialGrantedMomentContent.default.disclosure,
        primaryCTA: "Set up app blocking",
        dismissCTA: "Not now"
    )

    static func localized(locale: Locale = .current) -> UpdateTrialAnnouncementContent {
        let trial = TrialGrantedMomentContent.localized(locale: locale)
        return UpdateTrialAnnouncementContent(
            badge: trial.today.label,
            title: trial.title,
            titleAccent: trial.titleAccent,
            subtitle: trial.subtitle,
            perks: trial.today.perks.map {
                Perk(title: $0.title, symbolName: $0.symbolName)
            },
            disclosure: trial.disclosure,
            primaryCTA: PillieLocalization.string("global.action.continue", locale: locale),
            dismissCTA: PillieLocalization.string("global.action.not_now", locale: locale)
        )
    }
}

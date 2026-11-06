//
//  HonestPaywallBoardResolver.swift
//  Pillie
//

import Foundation

enum HonestPaywallBoardResolver {
    static func resolve(
        access: PlusAccessState,
        entry: PaywallEntryPoint,
        method: ContraceptiveMethod,
        calendar: Calendar,
        now: Date,
        locale: Locale,
        hardPaywallEnabled: Bool,
        termsCohort: TrialTermsCohort?
    ) -> HonestPaywallBoard? {
        guard !access.hasEntitlement else { return nil }

        if let clock = access.trialClock, clock.isActive(calendar: calendar, now: now) {
            return HonestPaywallBoard(
                moment: .duringTrial,
                story: HonestPaywallStoryFactory.duringTrial(
                    daysRemaining: clock.daysRemaining(calendar: calendar, now: now),
                    endsTonight: clock.endsTonight(calendar: calendar, now: now),
                    locale: locale
                )
            )
        }

        if access.trialGrantDate != nil, Self.showsTrialEndedBoard(entry) {
            let cohort = termsCohort
                ?? access.trialGrantDate.map(HardPaywallPolicy.cohort(forTrialGrantedAt:))
                ?? .postCutover
            let terms = HardPaywallPolicy.terms(
                for: cohort,
                hardPaywallEnabled: hardPaywallEnabled
            )
            return HonestPaywallBoard(
                moment: .trialEnded(terms),
                story: HonestPaywallStoryFactory.trialEnded(
                    terms: terms,
                    method: method,
                    locale: locale
                )
            )
        }

        return HonestPaywallBoard(
            moment: .settingsFree,
            story: HonestPaywallStoryFactory.settingsFree(method: method, locale: locale)
        )
    }

    private static func showsTrialEndedBoard(_ entry: PaywallEntryPoint) -> Bool {
        switch entry {
        case .trialEndAutoPresent, .protectionOffCard:
            true
        case .trialStatus, .settingsSubscription, .homeBlockingCard, .plusUpsell:
            false
        }
    }
}

#if DEBUG
extension PlusAccessState {
    static var trialActiveFixture: PlusAccessState {
        PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: Date(timeIntervalSince1970: 0)
        )
    }
}
#endif

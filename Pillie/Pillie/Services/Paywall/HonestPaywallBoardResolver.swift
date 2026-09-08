//
//  HonestPaywallBoardResolver.swift
//  Pillie
//

import Foundation

enum HonestPaywallBoardResolver {
    static func resolve(
        access: PlusAccessState,
        entry: PaywallEntryPoint,
        stats: TrialEndOwnStats?,
        calendar: Calendar,
        now: Date,
        locale: Locale,
        hardPaywallEnabled: Bool,
        termsCohort: TrialTermsCohort?
    ) -> HonestPaywallBoard? {
        guard !access.hasEntitlement else { return nil }

        if access.trialActive(calendar: calendar, now: now) {
            let grantDate = access.trialGrantDate ?? now
            let daysRemaining = ReverseTrialClock(grantDate: grantDate)
                .daysRemaining(calendar: calendar, now: now)
            return .duringTrial(
                HonestPaywallStoryFactory.duringTrial(
                    daysRemaining: daysRemaining,
                    locale: locale
                )
            )
        }

        if access.trialGrantDate != nil, entry == .trialEndAutoPresent {
            let cohort = termsCohort
                ?? access.trialGrantDate.map(HardPaywallPolicy.cohort(forTrialGrantedAt:))
                ?? .postCutover
            let terms = HardPaywallPolicy.terms(
                for: cohort,
                hardPaywallEnabled: hardPaywallEnabled
            )
            return .trialEnded(
                HonestPaywallStoryFactory.trialEnded(
                    stats: stats ?? .none,
                    terms: terms,
                    locale: locale
                )
            )
        }

        return .settingsFree(
            HonestPaywallStoryFactory.settingsFree(locale: locale)
        )
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

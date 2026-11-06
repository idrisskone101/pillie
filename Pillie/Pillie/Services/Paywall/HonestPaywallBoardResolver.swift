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
        design: PaywallDesign,
        trialStats: TrialEndOwnStats?,
        calendar: Calendar,
        now: Date,
        locale: Locale,
        hardPaywallEnabled: Bool,
        termsCohort: TrialTermsCohort?
    ) -> HonestPaywallBoard? {
        guard !access.hasEntitlement else { return nil }

        if let clock = access.trialClock, clock.isActive(calendar: calendar, now: now) {
            let daysRemaining = clock.daysRemaining(calendar: calendar, now: now)
            let layout: HonestPaywallLayout = switch design {
            case .s3:
                .s3(HonestPaywallStoryFactory.duringTrial(
                    daysRemaining: daysRemaining,
                    endsTonight: clock.endsTonight(calendar: calendar, now: now),
                    locale: locale
                ))
            case .classic:
                .classic(.duringTrial(ClassicPaywallStoryFactory.duringTrial(
                    daysRemaining: daysRemaining,
                    locale: locale
                )))
            }
            return HonestPaywallBoard(moment: .duringTrial, layout: layout)
        }

        if access.trialGrantDate != nil, Self.showsTrialEndedBoard(entry) {
            let cohort = termsCohort
                ?? access.trialGrantDate.map(HardPaywallPolicy.cohort(forTrialGrantedAt:))
                ?? .postCutover
            let terms = HardPaywallPolicy.terms(
                for: cohort,
                hardPaywallEnabled: hardPaywallEnabled
            )
            let layout: HonestPaywallLayout = switch design {
            case .s3:
                .s3(HonestPaywallStoryFactory.trialEnded(
                    terms: terms,
                    method: method,
                    locale: locale
                ))
            case .classic:
                .classic(.trialEnded(ClassicPaywallStoryFactory.trialEnded(
                    stats: trialStats ?? .none,
                    terms: terms,
                    locale: locale
                )))
            }
            return HonestPaywallBoard(moment: .trialEnded(terms), layout: layout)
        }

        let layout: HonestPaywallLayout = switch design {
        case .s3:
            .s3(HonestPaywallStoryFactory.settingsFree(method: method, locale: locale))
        case .classic:
            .classic(.settingsFree(ClassicPaywallStoryFactory.settingsFree(locale: locale)))
        }
        return HonestPaywallBoard(moment: .settingsFree, layout: layout)
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

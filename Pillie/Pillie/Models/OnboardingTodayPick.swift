//
//  OnboardingTodayPick.swift
//  Pillie
//

import Foundation

enum OnboardingTodayPick: Equatable {
    case pill(OnboardingDraft<TodayPillPick>)
    case dial(OnboardingDraft<RoutineDialPick>)

    static func load(method: ContraceptiveMethod, from defaults: UserDefaults = .standard) -> OnboardingTodayPick? {
        guard let dialMethod = RoutineDialMethod(method) else {
            return OnboardingDraft<TodayPillPick>.load(from: defaults).map(OnboardingTodayPick.pill)
        }
        guard let draft = OnboardingDraft<RoutineDialPick>.load(from: defaults), draft.pick.method == dialMethod else { return nil }
        return .dial(draft)
    }

    func commit(to store: PillStore) {
        switch self {
        case .pill(let draft): TodayPillCommit.run(draft, store: store)
        case .dial(let draft): TodayPillCommit.run(draft, store: store)
        }
    }
}

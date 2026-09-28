//
//  OnboardingTodayPick.swift
//  Pillie
//

import Foundation

/// What step 7 saved about today, committed to the store at step 8.
enum OnboardingTodayPick: Equatable {
    case pill(TodayPillPick)
    case dial(RoutineDialPick)

    /// The saved pick for this method, ignoring a draft left by another method.
    static func load(method: ContraceptiveMethod, from defaults: UserDefaults = .standard) -> OnboardingTodayPick? {
        guard let dialMethod = RoutineDialMethod(method) else {
            return TodayPillPick.load(from: defaults).map(OnboardingTodayPick.pill)
        }
        guard let pick = RoutineDialPick.load(from: defaults), pick.method == dialMethod else { return nil }
        return .dial(pick)
    }

    func commit(to store: PillStore) {
        switch self {
        case .pill(let pick): TodayPillCommit.run(pick, store: store)
        case .dial(let pick): TodayPillCommit.run(pick, store: store)
        }
    }
}

//
//  CyclePosition.swift
//  Pillie
//
//  A coarse "where are you in your routine" position for the Routine Basics Details
//  screen (#77). It is a friendlier, faster entry point than a bare day stepper: the
//  user taps Just starting / Mid-cycle / Near the end to jump the exact cycle day,
//  then fine-tunes if they want. Icons use a three-slot pack track (not sun/moon).
//  The exact day is what the production model stores
//  (`PillStore.startNewProtocol(cycleDay:)`), so this type only maps between the
//  coarse bucket and a clamped day — it never persists on its own.
//
//  Pure value type so the mapping is deterministic and unit-testable.
//

import Foundation

enum CyclePosition: String, CaseIterable, Identifiable {
    case justStarting
    case midCycle
    case nearEnd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .justStarting: return PillieLocalization.string("onboarding.cycle_position.just_starting")
        case .midCycle: return PillieLocalization.string("onboarding.cycle_position.mid_cycle")
        case .nearEnd: return PillieLocalization.string("onboarding.cycle_position.near_end")
        }
    }

    /// Which blister slot is lit in the pack-track icon (0 = start, 1 = mid, 2 = end).
    var packTrackActiveIndex: Int {
        switch self {
        case .justStarting: return 0
        case .midCycle: return 1
        case .nearEnd: return 2
        }
    }

    /// The representative cycle day for this coarse position within a cycle of
    /// `cycleLength`, always clamped to the valid `[1, cycleLength]` range.
    func cycleDay(in cycleLength: Int) -> Int {
        let length = max(1, cycleLength)
        switch self {
        case .justStarting:
            return 1
        case .midCycle:
            return min(length, max(1, (length + 1) / 2))
        case .nearEnd:
            return length
        }
    }

    /// The coarse bucket a given cycle day falls into, used to restore the toggle
    /// highlight from the stored day on back navigation. Out-of-range days clamp.
    static func position(forCycleDay day: Int, cycleLength: Int) -> CyclePosition {
        let length = max(1, cycleLength)
        let clampedDay = min(max(1, day), length)
        if clampedDay <= max(1, length / 3) {
            return .justStarting
        }
        if clampedDay <= max(2, (2 * length) / 3) {
            return .midCycle
        }
        return .nearEnd
    }
}

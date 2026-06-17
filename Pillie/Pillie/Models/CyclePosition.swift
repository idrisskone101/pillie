//
//  CyclePosition.swift
//  Pillie
//
//  A coarse "where are you in your routine" position for the Routine Basics Details
//  screen (#77). It is a friendlier, faster entry point than a bare day stepper: the
//  user taps Just starting / Mid-cycle / Near the end to jump the exact cycle day,
//  then fine-tunes if they want. The exact day is what the production model stores
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
        case .justStarting: return "Just starting"
        case .midCycle: return "Mid-cycle"
        case .nearEnd: return "Near the end"
        }
    }

    var symbolName: String {
        switch self {
        case .justStarting: return "sunrise.fill"
        case .midCycle: return "sun.max.fill"
        case .nearEnd: return "moon.stars.fill"
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

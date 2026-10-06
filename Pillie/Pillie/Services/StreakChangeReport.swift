//
//  StreakChangeReport.swift
//  Pillie
//

import Foundation

/// `streak_changed` (ENG-165). The streak is derived from day records, so a
/// change is seen by comparing it with the last value reported. The first
/// read on a device only stores a baseline, so an update never reports
/// an existing streak as new.
enum StreakChangeReport {
    enum Reason: String {
        case logged
        case missed
        case packChange = "pack_change"
        case undone
    }

    struct Change: Equatable {
        let from: Int
        let to: Int
        let reason: Reason
    }

    static let storageKey = "pillie_analytics_reported_streak"

    /// Without a `reason`, a rise reads as a log and a drop as a miss: a
    /// missed day only shows once Pillie runs.
    static func change(from previous: Int?, to current: Int, reason: Reason?) -> Change? {
        guard let previous, previous != current else { return nil }
        return Change(
            from: previous,
            to: current,
            reason: reason ?? (current > previous ? .logged : .missed)
        )
    }

    static func record(
        _ store: PillStore,
        reason: Reason? = nil,
        defaults: UserDefaults = .standard,
        telemetry: ProductAnalyticsTelemetry = .live
    ) {
        let current = store.currentStreak
        let previous = defaults.object(forKey: storageKey) as? Int
        guard previous != current else { return }
        defaults.set(current, forKey: storageKey)
        if let change = change(from: previous, to: current, reason: reason) {
            telemetry.streakChanged(change)
        }
    }
}

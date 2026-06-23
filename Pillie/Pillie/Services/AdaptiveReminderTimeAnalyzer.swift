//
//  AdaptiveReminderTimeAnalyzer.swift
//  Pillie
//

import Foundation

/// Pure, dependency-free analyzer for the Adaptive Reminder Time Suggestion.
///
/// Given a history of `(scheduledReminder, takenAt)` pairs plus the current
/// reminder time, the current moment, and the last dismissal date, it decides
/// whether the user consistently logs their action meaningfully later (or
/// earlier) than their scheduled reminder and, if so, proposes a shifted
/// reminder time rounded to the nearest five minutes.
///
/// This type performs no I/O, holds no references to analytics, persistence, or
/// SwiftData, and never emits telemetry. The on-device `takenAt` log-time signal
/// flows in purely as function input and never leaves the device through this
/// module.
struct AdaptiveReminderTimeAnalyzer {

    /// Tunable detection defaults. All durations are expressed in minutes/days.
    struct Configuration: Equatable {
        /// Minimum number of logged due actions required before suggesting.
        var minimumLogCount: Int = 10
        /// Only the most recent logs (by scheduled reminder) are considered.
        var maximumLogWindow: Int = 14
        /// Median offset magnitude (minutes) required to propose a shift.
        var minimumMedianOffsetMinutes: Int = 30
        /// Maximum allowed spread (inter-quartile range, minutes) — i.e. the
        /// offsets must be tightly clustered ("low variance").
        var maximumSpreadMinutes: Int = 30
        /// Cooldown window (days) after a dismissal before re-pitching.
        var cooldownDays: Int = 14
        /// Suggested times are rounded to a multiple of this many minutes.
        var roundingMinutes: Int = 5

        static let `default` = Configuration()
    }

    /// A proposed reminder time plus the signed delta (minutes) used to derive it.
    struct Suggestion: Equatable {
        var hour: Int
        var minute: Int
        /// Signed shift from the current reminder time, rounded to `roundingMinutes`.
        var deltaMinutes: Int
    }

    var configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Returns a suggested reminder time, or `nil` when no confident shift exists.
    ///
    /// - Parameters:
    ///   - logs: `(scheduledReminder, takenAt)` pairs for recent due actions.
    ///   - currentReminderHour: Current reminder hour (0...23).
    ///   - currentReminderMinute: Current reminder minute (0...59).
    ///   - now: The current moment (drives the cooldown check).
    ///   - lastDismissal: When the user last dismissed a suggestion, if ever.
    ///   - lastDismissedDelta: The delta the user last dismissed, if known. The
    ///     same delta is never re-pitched after a dismissal.
    func suggestion(
        logs: [(scheduledReminder: Date, takenAt: Date)],
        currentReminderHour: Int,
        currentReminderMinute: Int,
        now: Date,
        lastDismissal: Date?,
        lastDismissedDelta: Int? = nil
    ) -> Suggestion? {
        // Cooldown: never re-pitch within the cooldown window after a dismissal.
        if let lastDismissal {
            let cooldown = TimeInterval(configuration.cooldownDays) * 86_400
            if now.timeIntervalSince(lastDismissal) < cooldown {
                return nil
            }
        }

        // Consider only the most recent window of logs.
        let recent = logs
            .sorted { $0.scheduledReminder < $1.scheduledReminder }
            .suffix(configuration.maximumLogWindow)

        guard recent.count >= configuration.minimumLogCount else { return nil }

        // Offset (minutes) between when the action was taken and its scheduled reminder.
        let offsets = recent
            .map { $0.takenAt.timeIntervalSince($0.scheduledReminder) / 60.0 }
            .sorted()

        let medianOffset = Self.median(of: offsets)
        let spread = Self.interquartileRange(of: offsets)

        // Require a meaningful, tightly-clustered offset.
        guard abs(medianOffset) >= Double(configuration.minimumMedianOffsetMinutes) else { return nil }
        guard spread <= Double(configuration.maximumSpreadMinutes) else { return nil }

        // Shift toward the median, rounded to the nearest `roundingMinutes`.
        let rounding = max(1, configuration.roundingMinutes)
        let delta = Int((medianOffset / Double(rounding)).rounded()) * rounding
        guard delta != 0 else { return nil }

        // Never re-pitch a delta the user already dismissed.
        if let lastDismissedDelta, delta == lastDismissedDelta { return nil }

        let currentMinutes = currentReminderHour * 60 + currentReminderMinute
        let total = ((currentMinutes + delta) % 1440 + 1440) % 1440

        return Suggestion(hour: total / 60, minute: total % 60, deltaMinutes: delta)
    }

    // MARK: - Statistics

    private static func median(of sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let count = sorted.count
        if count % 2 == 1 {
            return sorted[count / 2]
        }
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    }

    /// Inter-quartile range (Q3 − Q1) as a robust, outlier-resistant spread.
    private static func interquartileRange(of sorted: [Double]) -> Double {
        guard sorted.count >= 2 else { return 0 }
        let count = sorted.count
        let lower = Array(sorted[0 ..< count / 2])
        let upper = count % 2 == 0
            ? Array(sorted[count / 2 ..< count])
            : Array(sorted[(count / 2 + 1) ..< count])
        return median(of: upper) - median(of: lower)
    }
}

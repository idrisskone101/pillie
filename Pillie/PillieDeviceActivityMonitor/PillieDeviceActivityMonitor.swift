//
//  PillieDeviceActivityMonitor.swift
//  PillieDeviceActivityMonitor
//
//  DeviceActivityMonitor extension that triggers app blocking
//  at reminder time and clears it at end of day.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import os

class PillieDeviceActivityMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    private static let logger = Logger(
        subsystem: "com.idrisskone.pillie.device-activity-monitor",
        category: "blocking"
    )

    private let defaults = AppGroupConstants.sharedDefaults

    private nonisolated static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: "Shield")
    }

    override nonisolated func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Self.logger.info("intervalDidStart fired for activity: \(activity.rawValue)")

        let defaults = self.defaults
        // Force disk refresh so we read the latest values written by the main app
        defaults?.synchronize()
        let now = Date()

        // Skip if blocking is disabled by user
        let blockingEnabled = defaults?.bool(forKey: AppGroupKeys.blockingEnabled, default: true) ?? true
        if !blockingEnabled {
            Self.logger.info("Skipping — blocking is disabled by user")
            return
        }

        // Blocking must never outlive Plus Access (#167 / ADR 0007): the main
        // app mirrors a coarse access-valid-until date into the App Group, so
        // an expired Reverse Trial stops blocking here even if the app is never
        // opened again. A missing mirror (legacy install) fails toward blocking.
        let accessValidUntil = defaults?.object(forKey: AppGroupKeys.plusAccessValidUntil) as? Double
        if !PlusAccessMirror.allowsBlocking(validUntilEpochSeconds: accessValidUntil, now: now) {
            Self.logger.info("Skipping — Plus Access expired; clearing any stale shields")
            clearShieldsAndState()
            return
        }

        // The daily DeviceActivity interval must still honor Pillie's actual
        // cycle. A periodic action-day mirror lets the extension clear shields
        // throughout break/passive days and resume on the next action day even
        // if the main app never wakes in between. A missing mirror preserves the
        // legacy fail-toward-blocking behavior until the next app launch.
        let blockingSchedule = BlockingScheduleMirror.decode(
            from: defaults?.data(forKey: BlockingScheduleMirror.storageKey)
        )
        let stamp = TodayTakenStamp(
            isTaken: defaults?.bool(forKey: AppGroupKeys.isTodayTaken) ?? false,
            epochDay: defaults?.object(forKey: AppGroupKeys.todayTakenEpochDay) as? Int
        )

        switch BlockingInterventionPolicy.decision(
            schedule: blockingSchedule,
            handledStamp: stamp,
            now: now
        ) {
        case .clearShields:
            if blockingSchedule?.requiresAction(on: now) == false {
                Self.logger.info("Skipping — no user action scheduled today; clearing stale shields")
            } else {
                Self.logger.info("Skipping — action already handled today; clearing stale shields")
            }
            clearShieldsAndState()
            return
        case .applyShields:
            break
        }

        // Load saved selection from App Group
        guard let data = defaults?.data(forKey: AppGroupKeys.familyActivitySelectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            Self.logger.warning("No selection data found in App Group defaults")
            return
        }

        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            Self.logger.info("Selection is empty — no apps or categories to block")
            return
        }

        Self.logger.info("Applying shields — apps: \(selection.applicationTokens.count), categories: \(selection.categoryTokens.count)")

        // Apply shields
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens

        defaults?.set(true, forKey: AppGroupKeys.blockingRequested)
        defaults?.set(
            Self.localized("shield.blocking_reason"),
            forKey: AppGroupKeys.blockingReason
        )
        defaults?.synchronize()

        Self.logger.info("Shields applied and state persisted")
    }

    override nonisolated func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        Self.logger.info("intervalDidEnd fired for activity: \(activity.rawValue)")

        // End-of-day cleanup: remove all shields
        clearShieldsAndState()

        Self.logger.info("Shields removed and state cleared")
    }

    /// Removes all shields and resets the shared blocking-requested state.
    private nonisolated func clearShieldsAndState() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        defaults?.set(false, forKey: AppGroupKeys.blockingRequested)
        defaults?.set("", forKey: AppGroupKeys.blockingReason)
        defaults?.synchronize()
    }
}

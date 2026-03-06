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

    override nonisolated func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Self.logger.info("intervalDidStart fired for activity: \(activity.rawValue)")

        let defaults = self.defaults
        // Force disk refresh so we read the latest values written by the main app
        defaults?.synchronize()

        // Skip if blocking is disabled by user
        let blockingEnabled = defaults?.bool(forKey: AppGroupKeys.blockingEnabled, default: true) ?? true
        if !blockingEnabled {
            Self.logger.info("Skipping — blocking is disabled by user")
            return
        }

        // Skip if user already took their action today
        let isTaken = defaults?.bool(forKey: AppGroupKeys.isTodayTaken) ?? false
        if isTaken {
            Self.logger.info("Skipping — isTodayTaken is true")
            return
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
        defaults?.set("Time for your contraceptive!", forKey: AppGroupKeys.blockingReason)
        defaults?.synchronize()

        Self.logger.info("Shields applied and state persisted")
    }

    override nonisolated func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        Self.logger.info("intervalDidEnd fired for activity: \(activity.rawValue)")

        // End-of-day cleanup: remove all shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        let defaults = self.defaults
        defaults?.set(false, forKey: AppGroupKeys.blockingRequested)
        defaults?.set("", forKey: AppGroupKeys.blockingReason)
        defaults?.synchronize()

        Self.logger.info("Shields removed and state cleared")
    }
}

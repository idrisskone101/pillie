//
//  ScreenTimeSharedState.swift
//  Pillie
//
//  Shared between main app and all extension targets.
//  Reads/writes Screen Time state via App Group UserDefaults.
//

import Foundation
import FamilyControls

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}

enum ScreenTimeSharedState {
    private static var defaults: UserDefaults? {
        AppGroupConstants.sharedDefaults
    }

    // MARK: - FamilyActivitySelection

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: AppGroupKeys.familyActivitySelectionData)
        defaults?.synchronize()
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: AppGroupKeys.familyActivitySelectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    // MARK: - Blocking State

    static var isBlockingRequested: Bool {
        get { defaults?.bool(forKey: AppGroupKeys.blockingRequested) ?? false }
        set {
            defaults?.set(newValue, forKey: AppGroupKeys.blockingRequested)
            defaults?.synchronize()
        }
    }

    static var blockingReason: String {
        get { defaults?.string(forKey: AppGroupKeys.blockingReason) ?? "" }
        set {
            defaults?.set(newValue, forKey: AppGroupKeys.blockingReason)
            defaults?.synchronize()
        }
    }

    // MARK: - Blocking Enabled (Master Toggle)

    static var isBlockingEnabled: Bool {
        get { defaults?.bool(forKey: AppGroupKeys.blockingEnabled, default: true) ?? true }
        set {
            defaults?.set(newValue, forKey: AppGroupKeys.blockingEnabled)
            defaults?.synchronize()
        }
    }

    // MARK: - Today Taken Flag

    /// Writes the flag together with the day it describes. The
    /// DeviceActivityMonitor extension rejects the flag when the stamp isn't
    /// today's, so yesterday's true can't cancel today's blocking when the
    /// app never ran overnight.
    static func setTodayTaken(_ isTaken: Bool, now: Date = Date()) {
        defaults?.set(isTaken, forKey: AppGroupKeys.isTodayTaken)
        defaults?.set(
            TodayTakenStamp.epochDay(for: now),
            forKey: AppGroupKeys.todayTakenEpochDay
        )
        defaults?.synchronize()
    }

    static var todayTakenStamp: TodayTakenStamp {
        TodayTakenStamp(
            isTaken: defaults?.bool(forKey: AppGroupKeys.isTodayTaken) ?? false,
            epochDay: defaults?.object(forKey: AppGroupKeys.todayTakenEpochDay) as? Int
        )
    }
}

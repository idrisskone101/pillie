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

    // MARK: - Plus Access Mirror

    /// The coarse access-valid-until mirror (#167): a derived copy of the
    /// authoritative Keychain/RevenueCat access state, refreshed on every
    /// `refreshPlusAccess`, so the DeviceActivityMonitor extension can
    /// self-disable blocking at expiry without the app ever opening.
    static func setPlusAccessValidUntil(_ date: Date) {
        defaults?.set(date.timeIntervalSince1970, forKey: AppGroupKeys.plusAccessValidUntil)
        defaults?.synchronize()
    }

    static var plusAccessValidUntilEpochSeconds: Double? {
        defaults?.object(forKey: AppGroupKeys.plusAccessValidUntil) as? Double
    }

    // MARK: - Blocking Schedule Mirror

    /// Mirrors a periodic action-day rule so the extension can distinguish due-
    /// action days from break/passive days while Pillie is suspended. Method and
    /// regimen labels are intentionally not persisted here.
    static func setBlockingScheduleMirror(_ schedule: BlockingScheduleMirror) {
        setBlockingScheduleMirror(schedule, in: defaults)
    }

    /// Injectable storage seam used by regression tests to exercise the same
    /// App Group writer without mutating the real shared suite.
    static func setBlockingScheduleMirror(
        _ schedule: BlockingScheduleMirror,
        in defaults: UserDefaults?
    ) {
        guard let data = schedule.encodedData() else { return }
        defaults?.set(data, forKey: BlockingScheduleMirror.storageKey)
        defaults?.synchronize()
    }

    static var blockingScheduleMirror: BlockingScheduleMirror? {
        BlockingScheduleMirror.decode(
            from: defaults?.data(forKey: BlockingScheduleMirror.storageKey)
        )
    }

    // MARK: - Today Handled Stamp (Legacy Taken Key)

    /// Writes the handled state (taken or no action scheduled) together with
    /// the day it describes. The
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

    // MARK: - Blocking Snooze

    static var blockingSnoozeUntil: Date? {
        get {
            guard let epoch = defaults?.object(forKey: AppGroupKeys.blockingSnoozeUntil) as? Double else {
                return nil
            }
            return Date(timeIntervalSince1970: epoch)
        }
        set {
            if let newValue {
                defaults?.set(newValue.timeIntervalSince1970, forKey: AppGroupKeys.blockingSnoozeUntil)
            } else {
                defaults?.removeObject(forKey: AppGroupKeys.blockingSnoozeUntil)
            }
            defaults?.synchronize()
        }
    }

    static var blockingSnoozeLedger: BlockingSnoozeLedger {
        get {
            guard let data = defaults?.data(forKey: AppGroupKeys.blockingSnoozeLedger),
                  let ledger = try? JSONDecoder().decode(BlockingSnoozeLedger.self, from: data) else {
                return .empty
            }
            return ledger
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults?.set(data, forKey: AppGroupKeys.blockingSnoozeLedger)
            defaults?.synchronize()
        }
    }

    static var blockingSnoozeIntervalMinutes: Int {
        get {
            let raw = defaults?.object(forKey: AppGroupKeys.blockingSnoozeIntervalMinutes) as? Int
                ?? BlockingSnoozePolicy.defaultIntervalMinutes
            return BlockingSnoozePolicy.normalizedInterval(raw)
        }
        set {
            defaults?.set(
                BlockingSnoozePolicy.normalizedInterval(newValue),
                forKey: AppGroupKeys.blockingSnoozeIntervalMinutes
            )
            defaults?.synchronize()
        }
    }

    static var blockingDueDayEpoch: Int? {
        get { defaults?.object(forKey: AppGroupKeys.blockingDueDayEpoch) as? Int }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: AppGroupKeys.blockingDueDayEpoch)
            } else {
                defaults?.removeObject(forKey: AppGroupKeys.blockingDueDayEpoch)
            }
            defaults?.synchronize()
        }
    }
}

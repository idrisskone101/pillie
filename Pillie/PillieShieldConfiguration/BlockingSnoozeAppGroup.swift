//
//  BlockingSnoozeAppGroup.swift
//  Foundation-only App Group accessors for the shield extensions.
//  Keep in sync with PillieShieldAction/BlockingSnoozeAppGroup.swift.
//

import Foundation

enum BlockingSnoozeAppGroup {
    private static var defaults: UserDefaults? {
        AppGroupConstants.sharedDefaults
    }

    static var intervalMinutes: Int {
        let raw = defaults?.object(forKey: AppGroupKeys.blockingSnoozeIntervalMinutes) as? Int
            ?? BlockingSnoozePolicy.defaultIntervalMinutes
        return BlockingSnoozePolicy.normalizedInterval(raw)
    }

    static var dueDayEpoch: Int? {
        defaults?.object(forKey: AppGroupKeys.blockingDueDayEpoch) as? Int
    }

    static var resolvedDueDayEpoch: Int {
        dueDayEpoch ?? Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
    }

    static var ledger: BlockingSnoozeLedger {
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

    static var until: Date? {
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

    static var isBlockingRequested: Bool {
        get { defaults?.bool(forKey: AppGroupKeys.blockingRequested) ?? false }
        set {
            defaults?.set(newValue, forKey: AppGroupKeys.blockingRequested)
            defaults?.synchronize()
        }
    }
}

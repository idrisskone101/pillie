//  The small UserDefaults records the win-back pushes (ENG-173) read and
//  write. None of it is user content.

import Foundation
import os

enum WinbackStorage {
    /// Foreground entries only. The background refresh task is not an open.
    static let lastAppOpenKey = "winbackLastAppOpen"
    static let scheduledSlotsKey = "winbackScheduledSlots"

    static func recordAppOpen(_ date: Date = Date(), in defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: lastAppOpenKey)
    }

    static func lastAppOpen(in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: lastAppOpenKey) as? Date
    }

    /// `winback_notification_scheduled` counts each slot once per install,
    /// however often a replan re-adds or rewords it.
    static func reportScheduled(_ slot: WinbackSlot, in defaults: UserDefaults = .standard) {
        let reported = defaults.array(forKey: scheduledSlotsKey) as? [Int] ?? []
        guard !reported.contains(slot.rawValue) else { return }
        defaults.set(reported + [slot.rawValue], forKey: scheduledSlotsKey)
        ProductAnalyticsTelemetry.live.winbackNotificationScheduled(slot: slot)
    }

    #if DEBUG
    /// QA reruns: a fresh trial gets fresh win-back records. The slot 2 arm
    /// stays, since it belongs to the install, not the trial.
    static func clear(in defaults: UserDefaults = .standard) {
        for key in [lastAppOpenKey, scheduledSlotsKey, WinbackExtendPitch.storageKey, WinbackOpen.storageKey] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif

    fileprivate static func decode<Value: Decodable>(
        _ type: Value.Type,
        forKey key: String,
        in defaults: UserDefaults
    ) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Pillie winback decode failed key=\(key, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    fileprivate static func encode<Value: Encodable>(_ value: Value, forKey key: String, in defaults: UserDefaults) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            logger.error("Pillie winback encode failed key=\(key, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private static let logger = Logger(subsystem: "com.idrisskone.pillie", category: "winback")
}

extension WinbackSlot2Arm {
    static let storageKey = "winbackSlot2Arm"

    /// 50/50 at random the first time it is read, then fixed for the install.
    static func assigned(in defaults: UserDefaults = .standard) -> WinbackSlot2Arm {
        if let raw = defaults.string(forKey: storageKey), let arm = WinbackSlot2Arm(rawValue: raw) {
            return arm
        }
        let arm: WinbackSlot2Arm = Bool.random() ? .challenger : .control
        defaults.set(arm.rawValue, forKey: storageKey)
        return arm
    }
}

extension WinbackExtendPitch {
    static let storageKey = "winbackExtendPitch"

    static func load(from defaults: UserDefaults = .standard) -> WinbackExtendPitch? {
        WinbackStorage.decode(WinbackExtendPitch.self, forKey: storageKey, in: defaults)
    }

    func save(to defaults: UserDefaults = .standard) {
        WinbackStorage.encode(self, forKey: Self.storageKey, in: defaults)
    }
}

extension WinbackOpen {
    static let storageKey = "winbackLastOpen"

    /// The last open, while it can still claim a conversion.
    static func recent(now: Date = Date(), in defaults: UserDefaults = .standard) -> WinbackOpen? {
        guard let open = WinbackStorage.decode(WinbackOpen.self, forKey: storageKey, in: defaults),
              open.attributes(at: now)
        else { return nil }
        return open
    }

    func save(to defaults: UserDefaults = .standard) {
        WinbackStorage.encode(self, forKey: Self.storageKey, in: defaults)
    }
}

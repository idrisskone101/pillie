//
//  PlusAccessMirror.swift
//  PillieDeviceActivityMonitor
//
//  Per-target copy — keep in sync with Pillie/Shared/PlusAccessMirror.swift.
//
//  The coarse access-valid-until mirror (issue #167 / ADR 0007): blocking must
//  never outlive Plus Access, even if the app is never opened after a Reverse
//  Trial expires. The Keychain grant timestamp stays authoritative for the
//  clock; the main app refreshes the derived date into the App Group whenever
//  access state changes, so this sandboxed side can self-disable at expiry.
//

import Foundation

enum PlusAccessMirror {
    /// The one-off DeviceActivity interval that starts when Plus Access ends.
    /// The monitor only runs its access check for it and never shields.
    static let expiryWakeActivityName = "pillie.plus-access.expiry"

    /// The extension-side check: whether the mirrored valid-until moment still
    /// covers `now`. Expiry ends blocking exactly at the stored moment, matching
    /// `ReverseTrialClock.isActive`. A missing mirror (legacy install that
    /// predates the key) fails toward blocking — the main app writes the mirror
    /// on its next open, and until then the pre-#167 behavior holds.
    static func allowsBlocking(validUntilEpochSeconds: Double?, now: Date) -> Bool {
        guard let validUntilEpochSeconds else { return true }
        return now.timeIntervalSince1970 < validUntilEpochSeconds
    }
}

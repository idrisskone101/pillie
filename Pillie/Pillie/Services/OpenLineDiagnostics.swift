//
//  OpenLineDiagnostics.swift
//  Pillie
//
//  Reads the live device/app diagnostics that seed an Open Line issue report
//  (#154). Deliberately separate from `OpenLine.swift`, which stays a pure,
//  Foundation-only value type: the body contract is pinned there by unit tests
//  against injected plain values, while this side gathers the real values from
//  `Bundle`/`UIDevice` at the call site. It reads device/app facts *only* — never
//  routine data — so nothing here can leak the user's method, cycle, or reminders.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

extension OpenLine.Diagnostics {
    /// The running app's and device's diagnostics. Not unit-tested by design —
    /// the pure value type is the tested contract; this only feeds it live values.
    /// Missing Info.plist keys fall back to an em dash so the footer stays legible.
    static func current() -> OpenLine.Diagnostics {
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"

        #if canImport(UIKit)
        let systemVersion = UIDevice.current.systemVersion
        #else
        let systemVersion = "—"
        #endif

        return OpenLine.Diagnostics(
            appVersion: appVersion,
            build: build,
            systemVersion: systemVersion,
            deviceModel: hardwareModelIdentifier()
        )
    }

    /// The hardware identifier (e.g. `iPhone17,1`). On simulator the running
    /// machine is the host Mac, so the real device is read from the environment;
    /// on device, `uname`'s machine field is the identifier.
    private static func hardwareModelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulated.isEmpty {
            return simulated
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { bytes -> String in
            let cString = bytes.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: cString)
        }
        return identifier.isEmpty ? "—" : identifier
    }
}

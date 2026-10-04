//
//  ShieldApplicationLimit.swift
//  Pillie
//

import ManagedSettings

enum ShieldApplicationLimit {
    /// ManagedSettings silently stops shielding every app once
    /// `shield.applications` holds more than 50 tokens.
    static let maximum = 50

    /// Over the cap, category shields still cover the apps inside picked categories.
    static func shieldable(_ tokens: Set<ApplicationToken>) -> Set<ApplicationToken>? {
        tokens.isEmpty || tokens.count > maximum ? nil : tokens
    }
}

//
//  ShieldApplicationLimit.swift
//  Shared limit — keep in sync with Pillie/Shared/ShieldApplicationLimit.swift
//

import ManagedSettings

enum ShieldApplicationLimit {
    /// ManagedSettings silently stops shielding every app once
    /// `shield.applications` holds more than 50 tokens.
    static let maximum = 50

    /// The app tokens safe to hand to `shield.applications`. Whole-category
    /// selections can push past the cap; the category shield still covers every
    /// app inside a picked category, so only individually picked apps outside
    /// those categories lose their shield in that case.
    static func shieldable(_ tokens: Set<ApplicationToken>) -> Set<ApplicationToken>? {
        tokens.isEmpty || tokens.count > maximum ? nil : tokens
    }
}

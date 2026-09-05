//
//  HistoryDiscoveryAnnouncement.swift
//  Pillie
//

import Foundation

/// One-shot "Days are tappable now" announcement for History day correction:
/// a pip on the History tab plus an inline banner. Both read the same flag so
/// dismissing one clears the other.
enum HistoryDiscoveryAnnouncement {
    static let storageKey = "historyDayCorrectionDiscoveryDismissed"

    /// Fresh installs never saw the inert calendar, so telling them days are
    /// tappable "now" is noise. Call once at launch, before any screen renders:
    /// when the flag has never been written and there is no prior app state,
    /// it is seeded as dismissed. Existing users keep the default (`false`) and
    /// see the announcement once.
    static func seedForFreshInstallIfNeeded(
        hasExistingAppState: Bool,
        defaults: UserDefaults = .standard
    ) {
        guard defaults.object(forKey: storageKey) == nil, !hasExistingAppState else { return }
        defaults.set(true, forKey: storageKey)
    }
}

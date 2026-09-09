import Foundation

/// Order for opening the Settings-style blocker editor.
///
/// FamilyControls presents its own system sheets. Those crash or bounce when
/// they stack on Pillie's 430pt `BlockedAppsEditor` sheet. Authorization has
/// to finish on a full-screen presenter first.
enum BlockedAppsLaunch: Equatable {
    case authorizeThenPresentEditor
    case presentEditor

    static func make(isAuthorized: Bool) -> Self {
        isAuthorized ? .presentEditor : .authorizeThenPresentEditor
    }
}

/// Whether `FamilyActivityPicker` may present.
enum BlockedAppsPickerGate: Equatable {
    case waitForAuthorization
    case presentPicker

    static func make(isAuthorized: Bool) -> Self {
        isAuthorized ? .presentPicker : .waitForAuthorization
    }
}

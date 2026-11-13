//
//  BlockedAppsEditorTypes.swift
//  Pillie
//
//  Where the blocked-apps editor stands with Screen Time access.
//

import Foundation

/// The editor's Screen Time stage. Apple's alert converts far better when the
/// user knows why it is coming, so an install that was never asked reads a
/// lead-in first and triggers the alert itself.
enum BlockedAppsAccessStage: Equatable {
    /// Never asked: say what the access is for and let the user start the request.
    case leadIn
    /// The request is with iOS. The editor shows, inert, until it answers.
    case requesting
    /// iOS refused: the reason and Try again.
    case refused
    case granted

    /// The stage a freshly opened editor starts on. An install that was
    /// refused before asks again on open, as the editor always has.
    static func opening(for status: AppBlockingManager.AuthorizationStatus) -> BlockedAppsAccessStage {
        switch status {
        case .approved: .granted
        case .notDetermined: .leadIn
        case .denied: .requesting
        }
    }

    static func resolved(isAuthorized: Bool) -> BlockedAppsAccessStage {
        isAuthorized ? .granted : .refused
    }

    /// Only a refused install asks without a tap; the lead-in waits for its button.
    var requestsOnOpen: Bool { self == .requesting }
}

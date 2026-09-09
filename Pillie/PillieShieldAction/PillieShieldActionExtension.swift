//
//  PillieShieldActionExtension.swift
//  PillieShieldAction
//
//  Handles button taps on the shield.
//

import ManagedSettings
import ManagedSettingsUI

class PillieShieldActionExtension: ShieldActionDelegate {
    override nonisolated func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override nonisolated func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override nonisolated func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    private nonisolated func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            return .close
        case .secondaryButtonPressed:
            return .close
        @unknown default:
            return .close
        }
    }
}

//
//  PillieShieldActionExtension.swift
//  PillieShieldAction
//
//  Handles button taps on the shield.
//

import Foundation
import ManagedSettings
import ManagedSettingsUI

class PillieShieldActionExtension: ShieldActionDelegate {
    override nonisolated func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override nonisolated func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override nonisolated func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}

//
//  PillieShieldActionExtension.swift
//  PillieShieldAction
//
//  Handles button taps on the shield.
//
//  Shield action extensions cannot launch other apps or open URLs, so
//  "Open Pillie" posts an immediate local notification whose tap launches
//  the app. The notification lands under the shielded app's dismissed screen.
//

import ManagedSettings
import ManagedSettingsUI
import UserNotifications

class PillieShieldActionExtension: ShieldActionDelegate {
    static let openAppNotificationIdentifier = "pillie.shield.open-app"
    static let requestKindKey = "pillie_request_kind"
    static let requestKindShieldOpen = "shield_open"

    override nonisolated func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    override nonisolated func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    override nonisolated func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    private nonisolated func respond(
        to action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            postOpenAppNotification { completionHandler(.close) }
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private nonisolated func postOpenAppNotification(completion: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = localized("shield.open_notification.title")
        content.body = localized("shield.open_notification.body")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = [Self.requestKindKey: Self.requestKindShieldOpen]

        let request = UNNotificationRequest(
            identifier: Self.openAppNotificationIdentifier,
            content: content,
            trigger: nil
        )
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.openAppNotificationIdentifier])
        center.add(request) { _ in completion() }
    }

    private nonisolated func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: "Shield")
    }
}

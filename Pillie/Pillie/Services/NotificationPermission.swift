//
//  NotificationPermission.swift
//  Pillie
//

import Foundation
import UserNotifications

/// Whether the person turned notifications off for Pillie. Only `.denied`
/// counts: Settings has no Notifications switch to turn on before the prompt.
@Observable
final class NotificationPermission {
    static let shared = NotificationPermission()

    private(set) var isDenied = false

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isDenied = settings.authorizationStatus == .denied
    }
}

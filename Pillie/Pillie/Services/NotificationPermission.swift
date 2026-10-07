//
//  NotificationPermission.swift
//  Pillie
//

import Foundation
import UserNotifications

/// Pillie's notification authorization, refreshed on demand.
@Observable
final class NotificationPermission {
    static let shared = NotificationPermission()

    private(set) var status: UNAuthorizationStatus = .notDetermined

    #if DEBUG
    /// `pillie://debug/trial-end-extend?notifications=on|off`: the simulator
    /// cannot grant notifications from the command line.
    var debugRemindersAllowedOverride: Bool?
    #endif

    /// Whether the person turned notifications off for Pillie. Only `.denied`
    /// counts: Settings has no Notifications switch to turn on before the prompt.
    var isDenied: Bool { status == .denied }

    /// Whether Pillie can schedule a reminder right now without asking first.
    var remindersAllowed: Bool {
        #if DEBUG
        if let debugRemindersAllowedOverride { return debugRemindersAllowedOverride }
        #endif
        return status.permitsNotificationScheduling
    }

    func refresh() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

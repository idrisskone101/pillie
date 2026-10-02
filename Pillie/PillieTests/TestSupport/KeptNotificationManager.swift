//
//  KeptNotificationManager.swift
//  PillieTests
//
//  Hosted XCTest aborts on the Xcode 27 beta when an implicitly @MainActor
//  class deallocates inside a test, so managers built with an injected
//  blocker-setup closure live for the whole process.
//

@testable import Pillie

@MainActor
enum KeptNotificationManager {
    private static var kept: [NotificationManager] = []

    static func make(hasBlockerSetup: @escaping () -> Bool) -> NotificationManager {
        let manager = NotificationManager(hasBlockerSetup: hasBlockerSetup)
        kept.append(manager)
        return manager
    }
}

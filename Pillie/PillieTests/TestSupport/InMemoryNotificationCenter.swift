//
//  InMemoryNotificationCenter.swift
//  PillieTests
//

import Foundation
import UserNotifications

@testable import Pillie

/// A notification center that keeps its pending requests in memory. Given a
/// `callbackQueue` it answers there, the way UNUserNotificationCenter answers on a
/// background queue; without one it answers inline.
nonisolated final class InMemoryNotificationCenter: NotificationCenterScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private let callbackQueue: DispatchQueue?
    private var pendingByID: [String: UNNotificationRequest] = [:]
    private var removedIDs: [String] = []
    private var callbacksInFlight = 0

    init(callbackQueue: DispatchQueue? = nil) {
        self.callbackQueue = callbackQueue
    }

    var pending: [UNNotificationRequest] { locked { Array(pendingByID.values) } }
    var removedPendingIDs: [String] { locked { removedIDs } }
    var isIdle: Bool { locked { callbacksInFlight == 0 } }

    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        answer { completion(.authorized) }
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    ) {
        answer { completionHandler(true, nil) }
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}

    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void) {
        let requests = pending
        answer { completionHandler(requests) }
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?
    ) {
        locked { pendingByID[request.identifier] = request }
        answer { completionHandler?(nil) }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        locked {
            identifiers.forEach { pendingByID[$0] = nil }
            removedIDs += identifiers
        }
    }

    func getDeliveredNotifications(completionHandler: @escaping @Sendable ([UNNotification]) -> Void) {
        answer { completionHandler([]) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}

    private func answer(_ callback: @escaping @Sendable () -> Void) {
        guard let callbackQueue else { return callback() }
        locked { callbacksInFlight += 1 }
        callbackQueue.async {
            callback()
            self.locked { self.callbacksInFlight -= 1 }
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

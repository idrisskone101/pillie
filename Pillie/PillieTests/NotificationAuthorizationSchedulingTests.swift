//
//  NotificationAuthorizationSchedulingTests.swift
//  PillieTests
//
//  Regression coverage for #201. Build 176 contained the onboarding-specific
//  authorization gate, but the routine setup step still reached the central
//  notification scheduler before the permission screen.
//

import Foundation
import Testing
import UserNotifications

@testable import Pillie

@MainActor
@Suite(.serialized)
struct NotificationAuthorizationSchedulingTests {
    @Test
    func `Not determined authorization adds no notification requests`() throws {
        let center = RecordingNotificationCenter(authorizationStatus: .notDetermined)
        let manager = NotificationManager(
            center: center,
            isRunningTests: false,
            scheduleDeviceActivityBlock: { _, _ in }
        )
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-07-14", hour: 8)
        )

        manager.rescheduleFromStore(fixture.store)

        #expect(
            center.addedRequests.isEmpty,
            "A fresh install must not create notification requests before authorization resolves."
        )
    }

    @Test
    func `Denied authorization adds no notification requests`() throws {
        let center = RecordingNotificationCenter(authorizationStatus: .denied)
        let manager = NotificationManager(
            center: center,
            isRunningTests: false,
            scheduleDeviceActivityBlock: { _, _ in }
        )
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-07-14", hour: 8)
        )

        manager.rescheduleFromStore(fixture.store)

        #expect(
            center.addedRequests.isEmpty,
            "A denial is product state and must not create code-2003 scheduling failures."
        )
    }

    @Test
    func `Authorized scheduling performs one reminder rebuild`() throws {
        let center = RecordingNotificationCenter(authorizationStatus: .authorized)
        let manager = NotificationManager(
            center: center,
            isRunningTests: false,
            scheduleDeviceActivityBlock: { _, _ in }
        )
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-07-14", hour: 8)
        )

        manager.rescheduleFromStore(fixture.store)

        #expect(center.authorizationStatusRequestCount == 1)
        #expect(center.pendingRequestFetchCount == 1)
        #expect(!center.addedRequests.isEmpty)
    }

    @Test(arguments: [UNAuthorizationStatus.provisional, .ephemeral])
    func `Schedulable authorization states add reminder requests`(_ status: UNAuthorizationStatus) throws {
        let center = RecordingNotificationCenter(authorizationStatus: status)
        let manager = NotificationManager(
            center: center,
            isRunningTests: false,
            scheduleDeviceActivityBlock: { _, _ in }
        )
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-07-14", hour: 8)
        )

        manager.rescheduleFromStore(fixture.store)

        #expect(!center.addedRequests.isEmpty)
    }

    @Test
    func `One failing reminder batch reports one scheduling error`() throws {
        let schedulingError = NSError(
            domain: UNErrorDomain,
            code: UNError.Code.notificationsNotAllowed.rawValue
        )
        let center = RecordingNotificationCenter(
            authorizationStatus: .authorized,
            addError: schedulingError
        )
        var reportedErrors: [any Error] = []
        let manager = NotificationManager(
            center: center,
            isRunningTests: false,
            scheduleDeviceActivityBlock: { _, _ in },
            trackSchedulingError: { reportedErrors.append($0) }
        )
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-07-14", hour: 8)
        )

        manager.rescheduleFromStore(fixture.store)

        #expect(center.addedRequests.count > 1)
        #expect(reportedErrors.count == 1)
    }
}

@MainActor
private final class RecordingNotificationCenter: NotificationCenterScheduling {
    private let authorizationStatus: UNAuthorizationStatus
    private let addError: (any Error)?
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var authorizationStatusRequestCount = 0
    private(set) var pendingRequestFetchCount = 0

    init(authorizationStatus: UNAuthorizationStatus, addError: (any Error)? = nil) {
        self.authorizationStatus = authorizationStatus
        self.addError = addError
    }

    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        authorizationStatusRequestCount += 1
        completion(authorizationStatus)
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    ) {
        completionHandler(false, nil)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}

    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void) {
        pendingRequestFetchCount += 1
        completionHandler([])
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?
    ) {
        addedRequests.append(request)
        completionHandler?(addError)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func getDeliveredNotifications(completionHandler: @escaping @Sendable ([UNNotification]) -> Void) {
        completionHandler([])
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}

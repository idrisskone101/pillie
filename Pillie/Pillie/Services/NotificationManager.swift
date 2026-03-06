//
//  NotificationManager.swift
//  Pillie
//

import Foundation
import UserNotifications
import os.signpost

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let legacyReminderID = "pillie_daily_reminder"
    private let legacyReminderPrefix = "pillie_due_reminder_"
    private let reminderPrefix = "pillie_reminder_"
    private let refillReminderPrefix = "pillie_refill_reminder_"
    private let categoryID = "PILL_REMINDER"
    private let markTakenActionID = "MARK_TAKEN_ACTION"
    private let snoozeActionID = "SNOOZE_ACTION"
    private let minimumSupportedEpoch: TimeInterval = -2_208_988_800 // 1900-01-01
    private let maximumSupportedEpoch: TimeInterval = 7_258_118_400 // 2200-01-01
    private static let perfLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.idrisskone.pillie", category: "NotificationPerf")

    private let maxPendingReminders = 64
    private let baseReminderCount = 7
    private let dueScanLimit = 120
    private let catchupDelayMinutes = 1
    private let rescheduleDebounceDelay: TimeInterval = 0.25
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private var pendingRescheduleWorkItem: DispatchWorkItem?

    private enum PayloadKey {
        static let dueDayEpoch = "dueDayEpoch"
        static let actionTypeRaw = "actionTypeRaw"
        static let requestKind = "requestKind"
    }

    private enum RequestKind: String {
        case base
        case retry
        case snooze
    }

    private struct SnoozeOverride {
        let dueDayEpoch: Int
        let firstFireDate: Date
    }

    struct ManagedReminderDiff {
        let stalePendingIDs: [String]
        let missingRequestIDs: [String]
        let staleDeliveredIDs: [String]
    }

    private init() {
        registerCategory()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard !isRunningTests else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error {
                print("Pillie notification auth error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Scheduling

    func requestReschedule(from store: PillStore, reason: String) {
        guard !isRunningTests else { return }
        DispatchQueue.main.async { [weak self, weak store] in
            guard let self, let store else { return }

            self.pendingRescheduleWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self, weak store] in
                guard let self, let store else { return }
                self.rescheduleFromStore(store, snoozeOverride: nil, reason: reason)
            }

            self.pendingRescheduleWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + self.rescheduleDebounceDelay, execute: workItem)
        }
    }

    func rescheduleFromStore(_ store: PillStore) {
        guard !isRunningTests else { return }
        pendingRescheduleWorkItem?.cancel()
        pendingRescheduleWorkItem = nil
        rescheduleFromStore(store, snoozeOverride: nil, reason: "immediate")
    }

    private func rescheduleFromStore(_ store: PillStore, snoozeOverride: SnoozeOverride?, reason: String) {
        let signpostID = OSSignpostID(log: Self.perfLog)
        os_signpost(.begin, log: Self.perfLog, name: "reminderRebuild", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.perfLog, name: "reminderRebuild", signpostID: signpostID) }

        os_signpost(.event, log: Self.perfLog, name: "reminderRebuildReason", "%{public}s", reason)

        // Warn if the user has disabled notifications — all scheduled reminders will silently fail
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                print("Pillie: notifications denied by user — reminders will not fire")
            }
        }

        // Ensure the extension has the latest taken state before scheduling
        store.syncTodayTakenToAppGroup()

        let requests = buildReminderRequests(store: store, now: Date(), snoozeOverride: snoozeOverride)
        applyManagedReminderRequests(requests)

        // Sync DeviceActivity schedule with reminder time
        AppBlockingManager.shared.scheduleDeviceActivityBlock(
            hour: store.reminderHour,
            minute: store.reminderMinute
        )
    }

    func cancelAllMethodReminders() {
        clearAllManagedPendingAndDelivered()
    }

    // MARK: - Category Registration

    private func registerCategory() {
        let markTakenAction = UNNotificationAction(
            identifier: markTakenActionID,
            title: "Mark as Taken",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionID,
            title: "Snooze",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [markTakenAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Action Handling

    func handleMarkTakenAction(store: PillStore, response: UNNotificationResponse) {
        let now = Date()
        let dueDate = dueDateFromPayload(userInfo: response.notification.request.content.userInfo)
            ?? Calendar.current.startOfDay(for: now)
        let dueEpoch = Int(Calendar.current.startOfDay(for: dueDate).timeIntervalSince1970)

        store.markActionAsTaken(on: dueDate)
        AppBlockingManager.shared.removeBlocking()
        clearReminders(forDueDayEpoch: dueEpoch)
        rescheduleFromStore(store)
    }

    func handleSnoozeAction(store: PillStore, response: UNNotificationResponse) {
        guard let dueDate = dueDateFromPayload(userInfo: response.notification.request.content.userInfo) else {
            rescheduleFromStore(store)
            return
        }

        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: dueDate)
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        // If it was already confirmed, just rebuild future reminders.
        if store.statusForDate(dueDay) == .taken {
            rescheduleFromStore(store)
            return
        }

        clearReminders(forDueDayEpoch: dueEpoch)
        let snoozeStart = Date().addingTimeInterval(TimeInterval(store.autoReminderIntervalMinutes * 60))
        rescheduleFromStore(
            store,
            snoozeOverride: SnoozeOverride(dueDayEpoch: dueEpoch, firstFireDate: snoozeStart),
            reason: "snooze"
        )
    }

    /// Returns the action identifier for "Mark as Taken"
    var markTakenAction: String { markTakenActionID }

    /// Returns the action identifier for "Snooze"
    var snoozeAction: String { snoozeActionID }

    // MARK: - Request Construction

    private func buildReminderRequests(
        store: PillStore,
        now: Date,
        snoozeOverride: SnoozeOverride?
    ) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let refillRequest = buildRefillReminderRequestIfNeeded(store: store, now: now, calendar: calendar)
        let dueReminderBudget = max(0, maxPendingReminders - (refillRequest == nil ? 0 : 1))
        guard dueReminderBudget > 0 else {
            return refillRequest.map { [$0] } ?? []
        }

        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: dueScanLimit,
            pack: store.pack
        )

        let statusByEpochDay = store.statusesByEpochDay(for: candidateDueActions.map(\.date))

        let dueActions = candidateDueActions.filter { action in
            let key = epochDay(for: action.date, calendar: calendar)
            return statusByEpochDay[key] != .taken
        }

        let baseDueActions = Array(dueActions.prefix(min(baseReminderCount, dueReminderBudget)))

        var requests: [UNNotificationRequest] = []
        var firstReminderByEpoch: [Int: Date] = [:]

        for due in baseDueActions {
            let dueDay = calendar.startOfDay(for: due.date)
            let dueEpoch = Int(dueDay.timeIntervalSince1970)
            let firstReminderDate = firstReminderDateForDueAction(
                dueDay: dueDay,
                now: now,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                snoozeOverride: snoozeOverride
            )

            guard let firstReminderDate,
                  firstReminderDate < endOfDayExclusive(for: dueDay, calendar: calendar) else {
                continue
            }

            let firstKind: RequestKind = (snoozeOverride?.dueDayEpoch == dueEpoch) ? .snooze : .base
            let baseRequest = makeRequest(
                for: due,
                fireDate: firstReminderDate,
                dueDayEpoch: dueEpoch,
                kind: firstKind,
                calendar: calendar
            )
            requests.append(baseRequest)
            firstReminderByEpoch[dueEpoch] = firstReminderDate
        }

        let remainingBudget = max(0, dueReminderBudget - requests.count)
        if remainingBudget > 0,
           let nearestDue = dueActions.first {
            let retryRequests = buildRetryRequests(
                for: nearestDue,
                firstReminderByEpoch: firstReminderByEpoch,
                now: now,
                intervalMinutes: store.autoReminderIntervalMinutes,
                budget: remainingBudget,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                snoozeOverride: snoozeOverride,
                calendar: calendar
            )

            requests.append(contentsOf: retryRequests)
        }

        var finalRequests = Array(requests.prefix(dueReminderBudget))
        if let refillRequest {
            finalRequests.append(refillRequest)
        }
        return Array(finalRequests.prefix(maxPendingReminders))
    }

    private func buildRetryRequests(
        for due: DoseScheduleAction,
        firstReminderByEpoch: [Int: Date],
        now: Date,
        intervalMinutes: Int,
        budget: Int,
        reminderHour: Int,
        reminderMinute: Int,
        snoozeOverride: SnoozeOverride?,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        guard budget > 0 else { return [] }

        let dueDay = calendar.startOfDay(for: due.date)
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        guard let firstReminderDate = firstReminderByEpoch[dueEpoch]
            ?? firstReminderDateForDueAction(
                dueDay: dueDay,
                now: now,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                snoozeOverride: snoozeOverride
            ) else {
            return []
        }

        let dayEnd = endOfDayExclusive(for: dueDay, calendar: calendar)
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        var nextFire = firstReminderDate.addingTimeInterval(interval)

        var requests: [UNNotificationRequest] = []
        while requests.count < budget && nextFire < dayEnd {
            requests.append(
                makeRequest(
                    for: due,
                    fireDate: nextFire,
                    dueDayEpoch: dueEpoch,
                    kind: .retry,
                    calendar: calendar
                )
            )
            nextFire.addTimeInterval(interval)
        }

        return requests
    }

    private func firstReminderDateForDueAction(
        dueDay: Date,
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        snoozeOverride: SnoozeOverride?
    ) -> Date? {
        let calendar = Calendar.current
        let dueEpoch = Int(dueDay.timeIntervalSince1970)

        if let snoozeOverride,
           snoozeOverride.dueDayEpoch == dueEpoch {
            return max(snoozeOverride.firstFireDate, now.addingTimeInterval(1))
        }

        let configured = reminderDate(on: dueDay, hour: reminderHour, minute: reminderMinute, calendar: calendar)

        if calendar.isDate(dueDay, inSameDayAs: now), configured <= now {
            return now.addingTimeInterval(TimeInterval(catchupDelayMinutes * 60))
        }

        return configured
    }

    private func reminderDate(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? day
    }

    private func endOfDayExclusive(for day: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 60 * 60)
    }

    private func buildRefillReminderRequestIfNeeded(
        store: PillStore,
        now: Date,
        calendar: Calendar
    ) -> UNNotificationRequest? {
        let today = calendar.startOfDay(for: now)
        let cycleLength = max(1, store.pack.cycleLength)
        let currentDayIndex = store.pack.cycleDayIndex(on: today, calendar: calendar)

        let supplyUnitsLeft: Int
        let thresholdDayIndex: Int

        switch store.pack.method {
        case .pill:
            let pillsLeft = min(store.refillReminderThresholdDays, cycleLength)
            supplyUnitsLeft = pillsLeft
            thresholdDayIndex = max(0, cycleLength - pillsLeft)
        case .patch:
            let patchesLeft = store.patchRestockReminderThresholdPatches
            supplyUnitsLeft = patchesLeft
            thresholdDayIndex = patchesLeft == 2 ? 0 : 7 // cycle day 1 or 8
        case .ring:
            return nil
        }

        let deltaToThresholdDay = (thresholdDayIndex - currentDayIndex + cycleLength) % cycleLength

        guard let triggerDay = calendar.date(byAdding: .day, value: deltaToThresholdDay, to: today) else {
            return nil
        }

        guard let fireDate = firstReminderDateForDueAction(
            dueDay: triggerDay,
            now: now,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            snoozeOverride: nil
        ),
        fireDate < endOfDayExclusive(for: triggerDay, calendar: calendar) else {
            return nil
        }

        let dueDayEpoch = Int(calendar.startOfDay(for: triggerDay).timeIntervalSince1970)
        return makeRefillRequest(
            fireDate: fireDate,
            dueDayEpoch: dueDayEpoch,
            supplyUnitsLeft: supplyUnitsLeft,
            method: store.pack.method,
            calendar: calendar
        )
    }

    private func makeRequest(
        for due: DoseScheduleAction,
        fireDate: Date,
        dueDayEpoch: Int,
        kind: RequestKind,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = due.reminderTitle
        content.body = due.reminderBody
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            PayloadKey.dueDayEpoch: dueDayEpoch,
            PayloadKey.actionTypeRaw: due.type.rawValue,
            PayloadKey.requestKind: kind.rawValue
        ]

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        if components.second == nil {
            components.second = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = reminderIdentifier(dueDayEpoch: dueDayEpoch, kind: kind, fireDate: fireDate)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func makeRefillRequest(
        fireDate: Date,
        dueDayEpoch: Int,
        supplyUnitsLeft: Int,
        method: ContraceptiveMethod,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        switch method {
        case .pill:
            content.title = "Refill Reminder"
            content.body = "You have \(supplyUnitsLeft) pills left. Time to call in your refill!"
        case .patch:
            let label = supplyUnitsLeft == 1 ? "patch" : "patches"
            content.title = "Restock Reminder"
            content.body = "You have \(supplyUnitsLeft) \(label) left. Time to restock your patches."
        case .ring:
            content.title = "Refill Reminder"
            content.body = "Time to check your contraception supply."
        }
        content.sound = .default

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        if components.second == nil {
            components.second = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = refillReminderIdentifier(dueDayEpoch: dueDayEpoch, fireDate: fireDate)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    // MARK: - Removal

    private func clearAllManagedPendingAndDelivered() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests
                .map(\.identifier)
                .filter(self.isManagedReminderID)
            if !ids.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }

        center.getDeliveredNotifications { [weak self] notifications in
            guard let self else { return }
            let ids = notifications
                .map { $0.request.identifier }
                .filter(self.isManagedReminderID)
            if !ids.isEmpty {
                self.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    private func clearReminders(forDueDayEpoch dueDayEpoch: Int) {
        let token = "_due_\(dueDayEpoch)_"

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests
                .map(\.identifier)
                .filter { self.isManagedReminderID($0) && $0.contains(token) }
            if !ids.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }

        center.getDeliveredNotifications { [weak self] notifications in
            guard let self else { return }
            let ids = notifications
                .map { $0.request.identifier }
                .filter { self.isManagedReminderID($0) && $0.contains(token) }
            if !ids.isEmpty {
                self.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    private func applyManagedReminderRequests(_ newRequests: [UNNotificationRequest]) {
        let managedNewRequests = newRequests.filter { isManagedReminderID($0.identifier) }
        let newRequestByID = Dictionary(uniqueKeysWithValues: managedNewRequests.map { ($0.identifier, $0) })
        let newManagedIDs = Array(newRequestByID.keys)

        center.getPendingNotificationRequests { [weak self] existingRequests in
            guard let self else { return }

            let existingManagedIDs = existingRequests
                .map(\.identifier)
                .filter(self.isManagedReminderID)

            let diff = Self.managedReminderDiff(
                existingPendingIDs: existingManagedIDs,
                existingDeliveredIDs: [],
                newRequestIDs: newManagedIDs
            )

            // No-op fast path: do not perform any writes when the managed ID set is unchanged.
            guard !diff.stalePendingIDs.isEmpty || !diff.missingRequestIDs.isEmpty else {
                return
            }

            if !diff.stalePendingIDs.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: diff.stalePendingIDs)
            }

            for id in diff.missingRequestIDs {
                guard let request = newRequestByID[id] else { continue }
                self.center.add(request) { error in
                    if let error {
                        print("Pillie schedule error: \(error.localizedDescription)")
                    }
                }
            }

            self.center.getDeliveredNotifications { [weak self] notifications in
                guard let self else { return }
                let existingManagedDeliveredIDs = notifications
                    .map { $0.request.identifier }
                    .filter(self.isManagedReminderID)
                let deliveredDiff = Self.managedReminderDiff(
                    existingPendingIDs: [],
                    existingDeliveredIDs: existingManagedDeliveredIDs,
                    newRequestIDs: newManagedIDs
                )

                if !deliveredDiff.staleDeliveredIDs.isEmpty {
                    self.center.removeDeliveredNotifications(withIdentifiers: deliveredDiff.staleDeliveredIDs)
                }
            }
        }
    }

    static func managedReminderDiff(
        existingPendingIDs: [String],
        existingDeliveredIDs: [String],
        newRequestIDs: [String]
    ) -> ManagedReminderDiff {
        let pendingSet = Set(existingPendingIDs)
        let deliveredSet = Set(existingDeliveredIDs)
        let newSet = Set(newRequestIDs)

        let stalePendingIDs = Array(pendingSet.subtracting(newSet)).sorted()
        let missingRequestIDs = Array(newSet.subtracting(pendingSet)).sorted()
        let staleDeliveredIDs = Array(deliveredSet.subtracting(newSet)).sorted()

        return ManagedReminderDiff(
            stalePendingIDs: stalePendingIDs,
            missingRequestIDs: missingRequestIDs,
            staleDeliveredIDs: staleDeliveredIDs
        )
    }

    // MARK: - ID + Payload

    private func reminderIdentifier(dueDayEpoch: Int, kind: RequestKind, fireDate: Date) -> String {
        "\(reminderPrefix)due_\(dueDayEpoch)_\(kind.rawValue)_\(Int(fireDate.timeIntervalSince1970))"
    }

    private func refillReminderIdentifier(dueDayEpoch: Int, fireDate: Date) -> String {
        "\(refillReminderPrefix)day_\(dueDayEpoch)_\(Int(fireDate.timeIntervalSince1970))"
    }

    private func isManagedReminderID(_ id: String) -> Bool {
        id == legacyReminderID
            || id.hasPrefix(legacyReminderPrefix)
            || id.hasPrefix(reminderPrefix)
            || id.hasPrefix(refillReminderPrefix)
    }

    private func dueDateFromPayload(userInfo: [AnyHashable: Any]) -> Date? {
        if let value = userInfo[PayloadKey.dueDayEpoch] as? Int {
            return dateFromEpoch(TimeInterval(value))
        }
        if let value = userInfo[PayloadKey.dueDayEpoch] as? Double {
            return dateFromEpoch(value)
        }
        if let value = userInfo[PayloadKey.dueDayEpoch] as? String,
           let epoch = Double(value) {
            return dateFromEpoch(epoch)
        }
        return nil
    }

    private func epochDay(for date: Date, calendar: Calendar) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    private func dateFromEpoch(_ epoch: TimeInterval) -> Date? {
        guard epoch.isFinite, epoch >= minimumSupportedEpoch, epoch <= maximumSupportedEpoch else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    #if DEBUG
    func managedRequestIdentifiersForTesting(store: PillStore, now: Date = Date()) -> [String] {
        buildReminderRequests(store: store, now: now, snoozeOverride: nil)
            .map(\.identifier)
            .sorted()
    }
    #endif
}

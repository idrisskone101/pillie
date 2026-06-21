//
//  NotificationManager.swift
//  Pillie
//

import Foundation
import UserNotifications
import os
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
    private let schedulePlanner = ReminderSchedulePlanner()
    private static let perfLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.idrisskone.pillie", category: "NotificationPerf")

    private let rescheduleDebounceDelay: TimeInterval = 0.25
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private var pendingRescheduleWorkItem: DispatchWorkItem?

    private enum PayloadKey {
        static let dueDayEpoch = "dueDayEpoch"
        static let actionTypeRaw = "actionTypeRaw"
        static let requestKind = "requestKind"
    }

    struct ManagedReminderDiff {
        let stalePendingIDs: [String]
        let missingRequestIDs: [String]
        let staleDeliveredIDs: [String]
    }

    private init() {
        registerCategory(includeSnooze: SubscriptionManager.shared.isPlus)
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard !isRunningTests else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error {
                os_log(.error, "Pillie notification auth error: %{public}@", error.localizedDescription)
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

    private func rescheduleFromStore(_ store: PillStore, snoozeOverride: ReminderSchedulePlanner.SnoozeOverride?, reason: String) {
        let signpostID = OSSignpostID(log: Self.perfLog)
        os_signpost(.begin, log: Self.perfLog, name: "reminderRebuild", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.perfLog, name: "reminderRebuild", signpostID: signpostID) }

        os_signpost(.event, log: Self.perfLog, name: "reminderRebuildReason", "%{public}s", reason)

        // Warn if the user has disabled notifications — all scheduled reminders will silently fail
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                os_log(.info, "Pillie: notifications denied by user — reminders will not fire")
            }
        }

        // Ensure the extension has the latest taken state before scheduling
        store.syncTodayTakenToAppGroup()

        // Keep the notification category in sync with the entitlement so the Snooze
        // action only appears for Plus users (Smart Reminders gate, ADR 0004).
        registerCategory(includeSnooze: SubscriptionManager.shared.isPlus)

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

    /// Registers the reminder category. The Snooze action is a Smart Reminders perk
    /// (a user-triggered follow-up re-fire) and is only included for Plus users; free
    /// users get a reminder with no Snooze action (ADR 0004).
    private func registerCategory(includeSnooze: Bool) {
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: reminderCategoryActions(includeSnooze: includeSnooze),
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    private func reminderCategoryActions(includeSnooze: Bool) -> [UNNotificationAction] {
        var actions = [
            UNNotificationAction(
                identifier: markTakenActionID,
                title: "Mark as Taken",
                options: []
            )
        ]
        if includeSnooze {
            actions.append(
                UNNotificationAction(
                    identifier: snoozeActionID,
                    title: "Snooze",
                    options: []
                )
            )
        }
        return actions
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
            snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(dueDayEpoch: dueEpoch, firstFireDate: snoozeStart),
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
        snoozeOverride: ReminderSchedulePlanner.SnoozeOverride?
    ) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )
        let intents = schedulePlanner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                pack: store.pack,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                autoReminderIntervalMinutes: store.autoReminderIntervalMinutes,
                autoReminderRetryLimit: store.autoReminderRetryLimit,
                refillReminderThresholdDays: store.refillReminderThresholdDays,
                patchRestockReminderThresholdPatches: store.patchRestockReminderThresholdPatches,
                candidateDueActions: candidateDueActions,
                statusByEpochDay: store.statusesByEpochDay(for: candidateDueActions.map(\.date)),
                snoozeOverride: snoozeOverride,
                smartRemindersEnabled: SubscriptionManager.shared.isPlus,
                calendar: calendar
            )
        )

        // Custom Reminder Messages (Pillie+): resolve once per reschedule. The build-time
        // gate lives in `CustomReminderCopy` — a non-Plus user's stored copy is ignored and
        // defaults fire. Enforcement is eventual: already-queued notifications revert on the
        // next reschedule (ADR 0004).
        let isPlus = SubscriptionManager.shared.isPlus
        let customTitle = store.customDueReminderTitle
        let customBody = store.customDueReminderBody

        return intents.map { intent in
            switch intent {
            case .due(let due):
                return makeRequest(
                    for: due,
                    calendar: calendar,
                    customTitle: customTitle,
                    customBody: customBody,
                    isPlus: isPlus
                )
            case .supply(let supply):
                return makeRefillRequest(for: supply, calendar: calendar)
            }
        }
    }

    private func makeRequest(
        for due: ReminderSchedulePlanner.DueReminderIntent,
        calendar: Calendar,
        customTitle: String,
        customBody: String,
        isPlus: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        if due.kind == .retry {
            content.title = "Still here when you're ready"
            content.body = "Take a tiny moment for your Pillie check-in."
        } else {
            // The base (and snooze re-fire) Due Action Reminder carries the user's custom
            // copy when Plus; any blank field falls back independently to the default
            // method-aware copy, so an empty notification can never fire.
            content.title = CustomReminderCopy.effective(
                custom: customTitle,
                default: due.action.reminderTitle,
                cap: CustomReminderCopy.titleCap,
                isPlus: isPlus
            )
            content.body = CustomReminderCopy.effective(
                custom: customBody,
                default: due.action.reminderBody,
                cap: CustomReminderCopy.bodyCap,
                isPlus: isPlus
            )
        }
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            PayloadKey.dueDayEpoch: due.dueDayEpoch,
            PayloadKey.actionTypeRaw: due.action.type.rawValue,
            PayloadKey.requestKind: due.kind.rawValue
        ]

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: due.fireDate)
        if components.second == nil {
            components.second = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = reminderIdentifier(dueDayEpoch: due.dueDayEpoch, kind: due.kind, fireDate: due.fireDate)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func makeRefillRequest(
        for supply: ReminderSchedulePlanner.SupplyReminderIntent,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        switch supply.method {
        case .pill:
            content.title = "Refill check-in"
            content.body = "Looks like you're getting low. A refill soon could save future stress."
        case .patch:
            content.title = "Patch restock check-in"
            content.body = "Looks like you're getting low. A restock soon could save future stress."
        case .ring:
            content.title = "Supply check-in"
            content.body = "Time to check your contraception supply."
        }
        content.sound = .default

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: supply.fireDate)
        if components.second == nil {
            components.second = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = refillReminderIdentifier(dueDayEpoch: supply.dueDayEpoch, fireDate: supply.fireDate)
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
                        os_log(.error, "Pillie schedule error: %{public}@", error.localizedDescription)
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

    private func reminderIdentifier(dueDayEpoch: Int, kind: ReminderSchedulePlanner.DueReminderKind, fireDate: Date) -> String {
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

    private func dateFromEpoch(_ epoch: TimeInterval) -> Date? {
        guard epoch.isFinite, epoch >= minimumSupportedEpoch, epoch <= maximumSupportedEpoch else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    #if DEBUG
    struct ReminderRequestDebugSummary: Hashable {
        let identifier: String
        let title: String
        let body: String
        let categoryIdentifier: String
        let dueDayEpoch: Int?
        let actionTypeRaw: String?
        let requestKind: String?
        let dateComponents: DateComponents

        var fireDate: Date? {
            Calendar.current.date(from: dateComponents)
        }
    }

    func reminderCategoryActionIdentifiersForTesting(isPlus: Bool) -> [String] {
        reminderCategoryActions(includeSnooze: isPlus).map(\.identifier)
    }

    func managedRequestIdentifiersForTesting(store: PillStore, now: Date = Date()) -> [String] {
        buildReminderRequests(store: store, now: now, snoozeOverride: nil)
            .map(\.identifier)
            .sorted()
    }

    func managedRequestSummariesForTesting(store: PillStore, now: Date = Date()) -> [ReminderRequestDebugSummary] {
        reminderRequestSummaries(
            from: buildReminderRequests(store: store, now: now, snoozeOverride: nil)
        )
    }

    func managedRequestSummariesForTesting(
        store: PillStore,
        now: Date,
        snoozeFirstFireDate: Date
    ) -> [ReminderRequestDebugSummary] {
        let dueDayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        return reminderRequestSummaries(
                from: buildReminderRequests(
                    store: store,
                    now: now,
                    snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                        dueDayEpoch: dueDayEpoch,
                        firstFireDate: snoozeFirstFireDate
                    )
                )
            )
        }

    private func reminderRequestSummaries(from requests: [UNNotificationRequest]) -> [ReminderRequestDebugSummary] {
        requests.compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
                return nil
            }
            let userInfo = request.content.userInfo
            return ReminderRequestDebugSummary(
                identifier: request.identifier,
                title: request.content.title,
                body: request.content.body,
                categoryIdentifier: request.content.categoryIdentifier,
                dueDayEpoch: userInfo[PayloadKey.dueDayEpoch] as? Int,
                actionTypeRaw: userInfo[PayloadKey.actionTypeRaw] as? String,
                requestKind: userInfo[PayloadKey.requestKind] as? String,
                dateComponents: trigger.dateComponents
            )
        }
        .sorted { $0.identifier < $1.identifier }
    }
    #endif
}

//
//  NotificationManager.swift
//  Pillie
//

import Foundation
import UserNotifications
import os
import os.signpost

protocol NotificationCenterScheduling: AnyObject {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void)
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    )
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void)
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable ((any Error)?) -> Void)?
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getDeliveredNotifications(completionHandler: @escaping @Sendable ([UNNotification]) -> Void)
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterScheduling {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }
}

private extension UNAuthorizationStatus {
    var permitsNotificationScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()

    private let center: any NotificationCenterScheduling
    private let legacyReminderID = "pillie_daily_reminder"
    private let legacyReminderPrefix = "pillie_due_reminder_"
    private let reminderPrefix = "pillie_reminder_"
    private let refillReminderPrefix = "pillie_refill_reminder_"
    private let cycleTransitionPrefix = "pillie_cycle_notice_"
    private let trialWarningPrefix = "pillie_trial_warning_"
    private let categoryID = "PILL_REMINDER"
    private let markTakenActionID = "MARK_TAKEN_ACTION"
    private let snoozeActionID = "SNOOZE_ACTION"
    private let minimumSupportedEpoch: TimeInterval = -2_208_988_800 // 1900-01-01
    private let maximumSupportedEpoch: TimeInterval = 7_258_118_400 // 2200-01-01
    private let schedulePlanner = ReminderSchedulePlanner()
    private static let perfLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.idrisskone.pillie", category: "NotificationPerf")

    private let rescheduleDebounceDelay: TimeInterval = 0.25
    private let isRunningTests: Bool
    private let scheduleDeviceActivityBlock: (_ hour: Int, _ minute: Int) -> Void
    private let trackSchedulingError: (_ error: any Error) -> Void
    private let hasPlusAccess: () -> Bool
    private let trackSmartReminderRetryScheduled: (_ count: Int) -> Void

    private var pendingRescheduleWorkItem: DispatchWorkItem?

    enum PayloadKey {
        static let dueDayEpoch = "dueDayEpoch"
        static let actionTypeRaw = "actionTypeRaw"
        static let requestKind = SmartReminderDelivery.requestKindKey
        // Shared with the delivery decision so the payload and the
        // `trial_expiry_warning_sent` reader can never drift apart (#168).
        static let trialWarningDay = TrialExpiryWarningDelivery.dayKey
    }

    private final class LedgerMutationBox {
        var ledger: ServedBaseReminderLedger
        init(_ ledger: ServedBaseReminderLedger) { self.ledger = ledger }
    }

    struct ManagedReminderDiff {
        let stalePendingIDs: [String]
        let missingRequestIDs: [String]
        let staleDeliveredIDs: [String]
    }

    init(
        center: any NotificationCenterScheduling = UNUserNotificationCenter.current(),
        isRunningTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
        scheduleDeviceActivityBlock: @escaping (_ hour: Int, _ minute: Int) -> Void = { hour, minute in
            AppBlockingManager.shared.scheduleDeviceActivityBlock(hour: hour, minute: minute)
        },
        trackSchedulingError: @escaping (_ error: any Error) -> Void = { error in
            os_log(.error, "Pillie schedule error: %{public}@", error.localizedDescription)
            ProductAnalyticsTelemetry.live.trackError(
                .notifications, error: error, context: ["operation": "schedule"]
            )
        },
        hasPlusAccess: @escaping () -> Bool = { SubscriptionManager.shared.hasPlusAccess },
        trackSmartReminderRetryScheduled: @escaping (_ count: Int) -> Void = {
            ProductAnalyticsTelemetry.live.smartReminderRetryScheduled(count: $0)
        }
    ) {
        self.center = center
        self.isRunningTests = isRunningTests
        self.scheduleDeviceActivityBlock = scheduleDeviceActivityBlock
        self.trackSchedulingError = trackSchedulingError
        self.hasPlusAccess = hasPlusAccess
        self.trackSmartReminderRetryScheduled = trackSmartReminderRetryScheduled
        registerCategory(includeSnooze: hasPlusAccess())
    }

    // MARK: - Authorization

    /// `completion` delivers the system prompt's coarse outcome on the main
    /// queue so the caller can report `notification_permission_completed`
    /// (#175). Never invoked under XCTest (the whole request is skipped).
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        guard !isRunningTests else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                os_log(.error, "Pillie notification auth error: %{public}@", error.localizedDescription)
                ProductAnalyticsTelemetry.live.trackError(
                    .notifications, error: error, context: ["operation": "authorization"]
                )
            }
            if let completion {
                DispatchQueue.main.async { completion(granted) }
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

        // Ensure the extension has the latest taken state before scheduling
        store.syncTodayTakenToAppGroup()

        // Keep the notification category in sync with the entitlement so the Snooze
        // action only appears for Plus users (Smart Reminders gate, ADR 0004).
        registerCategory(includeSnooze: hasPlusAccess())

        let now = Date()
        let calendar = Calendar.current

        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            self.center.getDeliveredNotifications { [weak self] delivered in
                guard let self else { return }

                let ledger = ServedBaseReminderLedger.load()
                let managedPending = pending.filter { self.isManagedReminderID($0.identifier) }
                let managedDelivered = delivered.filter { self.isManagedReminderID($0.request.identifier) }
                let servedMap = ledger.servedBaseFireDates(
                    pendingManagedRequests: managedPending,
                    deliveredManagedNotifications: managedDelivered,
                    now: now,
                    calendar: calendar
                )

                let requests = self.buildReminderRequests(
                    store: store,
                    now: now,
                    snoozeOverride: snoozeOverride,
                    locale: .current,
                    servedBaseFireDateByDueDayEpoch: servedMap
                )
                self.applyManagedReminderRequests(requests, store: store, ledger: ledger)
            }
        }

        // Sync DeviceActivity schedule with reminder time
        scheduleDeviceActivityBlock(store.reminderHour, store.reminderMinute)
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

    private func reminderCategoryActions(
        includeSnooze: Bool,
        locale: Locale = .current
    ) -> [UNNotificationAction] {
        var actions = [
            UNNotificationAction(
                identifier: markTakenActionID,
                title: PillieLocalization.string(
                    "notification.action.complete",
                    locale: locale
                ),
                options: []
            )
        ]
        if includeSnooze {
            actions.append(
                UNNotificationAction(
                    identifier: snoozeActionID,
                    title: PillieLocalization.string(
                        "notification.action.snooze",
                        locale: locale
                    ),
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
        var ledger = ServedBaseReminderLedger.load()
        ledger.clearServedRecordWhenTaken(dueDayEpoch: dueEpoch)
        ledger.save()
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
        snoozeOverride: ReminderSchedulePlanner.SnoozeOverride?,
        locale: Locale,
        servedBaseFireDateByDueDayEpoch: [Int: Date]
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
                smartRemindersEnabled: hasPlusAccess(),
                cycleTransitionEnabled: store.cycleTransitionNoticeEnabled,
                trialGrantDate: SubscriptionManager.shared.trialGrantDate,
                hasEntitlement: SubscriptionManager.shared.hasEntitlement,
                servedBaseFireDateByDueDayEpoch: servedBaseFireDateByDueDayEpoch,
                calendar: calendar
            )
        )

        // Custom Reminder Messages (Pillie+): resolve once per reschedule. The build-time
        // gate lives in `CustomReminderCopy` — a non-Plus user's stored copy is ignored and
        // defaults fire. Enforcement is eventual: already-queued notifications revert on the
        // next reschedule (ADR 0004).
        let isPlus = hasPlusAccess()
        let customTitle = store.customDueReminderTitle
        let customBody = store.customDueReminderBody
        let customRetryTitle = store.customRetryReminderTitle
        let customRetryBody = store.customRetryReminderBody

        return intents.map { intent in
            switch intent {
            case .due(let due):
                return makeRequest(
                    for: due,
                    calendar: calendar,
                    customTitle: customTitle,
                    customBody: customBody,
                    customRetryTitle: customRetryTitle,
                    customRetryBody: customRetryBody,
                    isPlus: isPlus
                )
            case .supply(let supply):
                return makeRefillRequest(for: supply, calendar: calendar)
            case .cycleTransition(let notice):
                return makeCycleTransitionRequest(for: notice, calendar: calendar)
            case .trialExpiryWarning(let warning):
                return makeTrialWarningRequest(
                    for: warning,
                    calendar: calendar,
                    locale: locale
                )
            }
        }
    }

    /// Builds a Reverse Trial expiry warning (#168). Copy is Pillie-authored
    /// (`TrialExpiryWarningCopy`) — informational, so no category/actions.
    private func makeTrialWarningRequest(
        for warning: ReminderSchedulePlanner.TrialExpiryWarningIntent,
        calendar: Calendar,
        locale: Locale
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = TrialExpiryWarningCopy.title(day: warning.day, locale: locale)
        content.body = TrialExpiryWarningCopy.body(day: warning.day, locale: locale)
        content.sound = .default
        content.userInfo = [
            PayloadKey.requestKind: TrialExpiryWarningDelivery.requestKindValue,
            PayloadKey.trialWarningDay: warning.day
        ]

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: warning.fireDate)
        if components.second == nil {
            components.second = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = trialWarningIdentifier(day: warning.day, fireDate: warning.fireDate)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// Default copy for the Auto-Reminder Retry, used as the fallback when a custom retry
    /// field is blank or the user is not Plus.
    static var defaultRetryTitle: String {
        PillieLocalization.string("notification.followup.title")
    }
    static var defaultRetryBody: String {
        PillieLocalization.string("notification.followup.body")
    }

    private func makeRequest(
        for due: ReminderSchedulePlanner.DueReminderIntent,
        calendar: Calendar,
        customTitle: String,
        customBody: String,
        customRetryTitle: String,
        customRetryBody: String,
        isPlus: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        if due.kind == .retry {
            // The Auto-Reminder Retry carries the user's custom follow-up copy when Plus;
            // each field falls back independently to the default retry copy when blank, so
            // an empty notification can never fire (same gate as the base reminder).
            content.title = CustomReminderCopy.effective(
                custom: customRetryTitle,
                default: Self.defaultRetryTitle,
                cap: CustomReminderCopy.titleCap,
                isPlus: isPlus
            )
            content.body = CustomReminderCopy.effective(
                custom: customRetryBody,
                default: Self.defaultRetryBody,
                cap: CustomReminderCopy.bodyCap,
                isPlus: isPlus
            )
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
            content.title = PillieLocalization.string("notification.refill.title")
            content.body = PillieLocalization.string("notification.refill.body")
        case .patch:
            content.title = PillieLocalization.string("notification.refill.patch.title")
            content.body = PillieLocalization.string("notification.refill.patch.body")
        case .ring:
            content.title = PillieLocalization.string("notification.refill.ring.title")
            content.body = PillieLocalization.string("notification.refill.ring.body")
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

    /// Builds the free Cycle Transition Notice (#123). Copy is Pillie-authored and
    /// method-aware (`CycleTransitionCopy`) — never the user's custom reminder copy, since
    /// this is not part of the Custom Reminder Message perk. The notice is informational,
    /// so it carries no category/actions (no Mark as Taken / Snooze).
    private func makeCycleTransitionRequest(
        for notice: ReminderSchedulePlanner.CycleTransitionIntent,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = CycleTransitionCopy.title(for: notice.method)
        content.body = CycleTransitionCopy.body(
            for: notice.method,
            resumeDate: notice.resumeDate,
            calendar: calendar
        )
        content.sound = .default
        content.userInfo = [
            PayloadKey.dueDayEpoch: notice.transitionDayEpoch,
            PayloadKey.requestKind: "cycleTransition"
        ]

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notice.fireDate)
        if components.second == nil {
            components.second = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = cycleTransitionIdentifier(transitionDayEpoch: notice.transitionDayEpoch, fireDate: notice.fireDate)
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

    private func applyManagedReminderRequests(
        _ newRequests: [UNNotificationRequest],
        store: PillStore,
        ledger: ServedBaseReminderLedger
    ) {
        center.getAuthorizationStatus { [weak self] status in
            guard let self else { return }
            guard status.permitsNotificationScheduling else {
                if status == .denied {
                    os_log(.info, "Pillie: notifications denied by user — reminders will not fire")
                }
                return
            }
            self.applyAuthorizedManagedReminderRequests(newRequests, store: store, ledger: ledger)
        }
    }

    private func applyAuthorizedManagedReminderRequests(
        _ newRequests: [UNNotificationRequest],
        store: PillStore,
        ledger: ServedBaseReminderLedger
    ) {
        let managedNewRequests = newRequests.filter { isManagedReminderID($0.identifier) }
        let newRequestByID = Dictionary(uniqueKeysWithValues: managedNewRequests.map { ($0.identifier, $0) })
        let newManagedIDs = Array(newRequestByID.keys)
        let errorReporter = NotificationScheduleBatchErrorReporter(report: trackSchedulingError)
        let ledgerBox = LedgerMutationBox(ledger)
        let calendar = Calendar.current

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
                    if error == nil,
                       request.content.userInfo[PayloadKey.requestKind] as? String
                        == ReminderSchedulePlanner.DueReminderKind.base.rawValue,
                       let dueEpoch = request.content.userInfo[PayloadKey.dueDayEpoch] as? Int,
                       let fireDate = Self.fireDate(from: request) {
                        ledgerBox.ledger.recordScheduled(dueDayEpoch: dueEpoch, fireDate: fireDate)
                        let candidateDates = DoseScheduleEngine.nextDueActions(
                            from: Date(),
                            limit: ReminderSchedulePlanner.dueScanLimit,
                            pack: store.pack
                        ).map(\.date)
                        let takenEpochs = Set(
                            store.statusesByEpochDay(for: candidateDates).compactMap { epoch, status in
                                status == .taken ? epoch : nil
                            }
                        )
                        ledgerBox.ledger.prune(
                            takenDueDayEpochs: takenEpochs,
                            todayStart: calendar.startOfDay(for: Date()),
                            calendar: calendar
                        )
                        ledgerBox.ledger.save()
                    }
                    if let error {
                        errorReporter.reportOnce(error)
                    }
                }
            }

            let scheduledRetryCount = diff.missingRequestIDs.reduce(into: 0) { count, id in
                guard let request = newRequestByID[id],
                      request.content.userInfo[PayloadKey.requestKind] as? String
                        == ReminderSchedulePlanner.DueReminderKind.retry.rawValue else { return }
                count += 1
            }
            if scheduledRetryCount > 0 {
                self.trackSmartReminderRetryScheduled(scheduledRetryCount)
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

    private final class NotificationScheduleBatchErrorReporter: @unchecked Sendable {
        private let lock = NSLock()
        private var didReport = false
        private let report: (_ error: any Error) -> Void

        init(report: @escaping (_ error: any Error) -> Void) {
            self.report = report
        }

        func reportOnce(_ error: any Error) {
            lock.lock()
            guard !didReport else {
                lock.unlock()
                return
            }
            didReport = true
            lock.unlock()
            report(error)
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

    private func cycleTransitionIdentifier(transitionDayEpoch: Int, fireDate: Date) -> String {
        "\(cycleTransitionPrefix)day_\(transitionDayEpoch)_\(Int(fireDate.timeIntervalSince1970))"
    }

    private func trialWarningIdentifier(day: Int, fireDate: Date) -> String {
        "\(trialWarningPrefix)day_\(day)_\(Int(fireDate.timeIntervalSince1970))"
    }

    private func isManagedReminderID(_ id: String) -> Bool {
        id == legacyReminderID
            || id.hasPrefix(legacyReminderPrefix)
            || id.hasPrefix(reminderPrefix)
            || id.hasPrefix(refillReminderPrefix)
            || id.hasPrefix(cycleTransitionPrefix)
            || id.hasPrefix(trialWarningPrefix)
    }

    static func fireDate(from request: UNNotificationRequest) -> Date? {
        if let trigger = request.trigger as? UNCalendarNotificationTrigger,
           let date = Calendar.current.date(from: trigger.dateComponents) {
            return date
        }

        guard let lastComponent = request.identifier.split(separator: "_").last,
              let fireEpoch = TimeInterval(lastComponent) else {
            return nil
        }
        return Date(timeIntervalSince1970: fireEpoch)
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
        let trialWarningDay: Int?
        let dateComponents: DateComponents

        var fireDate: Date? {
            Calendar.current.date(from: dateComponents)
        }
    }

    func reminderCategoryActionIdentifiersForTesting(isPlus: Bool) -> [String] {
        reminderCategoryActions(includeSnooze: isPlus).map(\.identifier)
    }

    func reminderCategoryActionTitlesForTesting(
        isPlus: Bool,
        locale: Locale = .current
    ) -> [String] {
        reminderCategoryActions(includeSnooze: isPlus, locale: locale).map(\.title)
    }

    func managedRequestIdentifiersForTesting(store: PillStore, now: Date = Date()) -> [String] {
        buildReminderRequests(
            store: store,
            now: now,
            snoozeOverride: nil,
            locale: .current,
            servedBaseFireDateByDueDayEpoch: [:]
        )
            .map(\.identifier)
            .sorted()
    }

    func managedRequestSummariesForTesting(
        store: PillStore,
        now: Date = Date(),
        locale: Locale = .current
    ) -> [ReminderRequestDebugSummary] {
        reminderRequestSummaries(
            from: buildReminderRequests(
                store: store,
                now: now,
                snoozeOverride: nil,
                locale: locale,
                servedBaseFireDateByDueDayEpoch: [:]
            )
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
                    ),
                    locale: .current,
                    servedBaseFireDateByDueDayEpoch: [:]
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
                trialWarningDay: userInfo[PayloadKey.trialWarningDay] as? Int,
                dateComponents: trigger.dateComponents
            )
        }
        .sorted { $0.identifier < $1.identifier }
    }
    #endif
}

import UIKit
import UserNotifications
import BackgroundTasks
import os

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var store: PillStore?
    #if DEBUG
    private var memoryWarningObserver: NSObjectProtocol?
    #endif

    private static let bgTaskID = "com.idrisskone.pillie.screentime-reconcile"
    private static var isRunningTests: Bool {
        ProcessRuntime.isRunningTests
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register BGAppRefreshTask as fallback for Screen Time reconciliation
        if !Self.isRunningTests {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: nil) { task in
                guard let refreshTask = task as? BGAppRefreshTask else { return }
                self.handleScreenTimeReconcileTask(refreshTask)
            }
        }

        #if DEBUG
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            let uptime = String(format: "%.1f", ProcessInfo.processInfo.systemUptime)
            print("Pillie DEBUG memory warning received at uptime \(uptime)s")
        }
        #endif

        // Configure AppsFlyer attribution. Keys/delegate are set here so they are in
        // place before the first didBecomeActive; configure() registers the observer
        // that sends the launch. Skipped during XCTest (no network in tests; avoids
        // the @MainActor deinit instability on the Xcode 27 beta).
        if !Self.isRunningTests {
            AppsFlyerManager.shared.configure()
        }

        return true
    }

    deinit {
        #if DEBUG
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        #endif
    }

    // Show notifications even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        recordTrialWarningDeliveryIfNeeded(userInfo: notification.request.content.userInfo)
        recordSmartReminderFireIfNeeded(request: notification.request)
        // Foreground fallback: apply blocking when reminder fires while app is open
        if let store = Self.store, !store.isTodayHandled {
            AppBlockingManager.shared.applyBlocking(reason: store.pack.method.blockingReasonText)
        }
        completionHandler([.banner, .sound])
    }

    /// Records `trial_expiry_warning_sent` with `day: 10 | 13` when a trial
    /// expiry warning is delivered (foreground) or handled (tapped) — at most
    /// once per day value, so a banner later tapped never double-counts (#168).
    private func recordTrialWarningDeliveryIfNeeded(userInfo: [AnyHashable: Any]) {
        let defaults = UserDefaults.standard
        let sentDays = defaults.array(forKey: TrialExpiryWarningDelivery.sentDaysStorageKey) as? [Int] ?? []
        guard let day = TrialExpiryWarningDelivery.day(fromUserInfo: userInfo, alreadySentDays: sentDays) else {
            return
        }
        defaults.set(sentDays + [day], forKey: TrialExpiryWarningDelivery.sentDaysStorageKey)
        ProductAnalyticsTelemetry.live.trialExpiryWarningSent(day: day)
    }

    private func recordSmartReminderFireIfNeeded(request: UNNotificationRequest) {
        let defaults = UserDefaults.standard
        let recordedIdentifiers = defaults.stringArray(
            forKey: SmartReminderDelivery.firedRequestIdentifiersStorageKey
        ) ?? []
        let requestKind = request.content.userInfo[SmartReminderDelivery.requestKindKey] as? String
        guard SmartReminderDelivery.shouldRecordFire(
            requestIdentifier: request.identifier,
            requestKind: requestKind,
            alreadyRecordedRequestIdentifiers: recordedIdentifiers
        ) else { return }

        // Request ids contain only Pillie's own kind/day/timestamp tokens. Keep a
        // small rolling dedupe window locally; the identifier is never captured.
        defaults.set(
            Array((recordedIdentifiers + [request.identifier]).suffix(64)),
            forKey: SmartReminderDelivery.firedRequestIdentifiersStorageKey
        )
        ProductAnalyticsTelemetry.live.smartReminderRetryFired()
    }

    private func recordSmartReminderOutcomeIfNeeded(response: UNNotificationResponse) {
        let requestKind = response.notification.request.content.userInfo[
            SmartReminderDelivery.requestKindKey
        ] as? String
        guard let outcome = SmartReminderDelivery.outcome(
            requestKind: requestKind,
            actionIdentifier: response.actionIdentifier,
            markTakenActionIdentifier: NotificationManager.shared.markTakenAction,
            snoozeActionIdentifier: NotificationManager.shared.snoozeAction,
            defaultActionIdentifier: UNNotificationDefaultActionIdentifier
        ) else { return }
        ProductAnalyticsTelemetry.live.smartReminderOutcome(outcome)
    }

    // Handle notification action buttons
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        recordTrialWarningDeliveryIfNeeded(userInfo: response.notification.request.content.userInfo)
        recordSmartReminderFireIfNeeded(request: response.notification.request)
        recordSmartReminderOutcomeIfNeeded(response: response)

        guard let store = Self.store else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case NotificationManager.shared.markTakenAction:
            NotificationManager.shared.handleMarkTakenAction(store: store, response: response)
        case NotificationManager.shared.snoozeAction:
            NotificationManager.shared.handleSnoozeAction(store: store, response: response)
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification banner — apply blocking immediately
            if !store.isTodayHandled {
                AppBlockingManager.shared.applyBlocking(reason: store.pack.method.blockingReasonText)
            }
        default:
            break
        }
        completionHandler()
    }

    // MARK: - BGAppRefreshTask

    private func handleScreenTimeReconcileTask(_ task: BGAppRefreshTask) {
        guard let store = Self.store else {
            task.setTaskCompleted(success: false)
            return
        }

        store.syncTodayTakenToAppGroup()
        AppBlockingManager.shared.reconcileBlockingState(
            isTodayHandled: store.isTodayHandled,
            liveDay: store.today,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
        NotificationManager.shared.rescheduleFromStore(store)

        task.setTaskCompleted(success: true)

        // Re-schedule for next opportunity
        Self.scheduleScreenTimeReconcileTask()
    }

    static func scheduleScreenTimeReconcileTask() {
        guard !isRunningTests else { return }
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            os_log(.error, "Pillie BGTask schedule error: %{public}@", error.localizedDescription)
        }
    }
}

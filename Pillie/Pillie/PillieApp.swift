//
//  PillieApp.swift
//  Pillie
//
//  Created by Idriss Kone on 2026-02-17.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import FamilyControls
import BackgroundTasks
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var store: PillStore?
    #if DEBUG
    private var memoryWarningObserver: NSObjectProtocol?
    #endif

    private static let bgTaskID = "com.idrisskone.pillie.screentime-reconcile"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register BGAppRefreshTask as fallback for Screen Time reconciliation
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleScreenTimeReconcileTask(refreshTask)
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
        // Foreground fallback: apply blocking when reminder fires while app is open
        if let store = Self.store, !store.isTodayHandled {
            AppBlockingManager.shared.applyBlocking(reason: store.pack.method.blockingReasonText)
        }
        completionHandler([.banner, .sound])
    }

    // Handle notification action buttons
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
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
            isTodayTaken: store.isTodayHandled,
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
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Pillie BGTask schedule error: \(error.localizedDescription)")
        }
    }
}

@main
struct PillieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    @State private var store: PillStore

    init() {
        PillieFontRegistration.registerFontsIfNeeded()

        let schema = Schema([PillPack.self, PillDay.self])
        // Default app-support URL for now.
        // Phase 5: switch to shared App Group container URL.
        let config = ModelConfiguration(for: PillPack.self, PillDay.self)
        let container = try! ModelContainer(for: schema, configurations: [config])
        self.container = container

        DataMigration.migrateFromUserDefaultsIfNeeded(context: container.mainContext)

        let initialStore = PillStore(modelContext: container.mainContext)
        self._store = State(initialValue: initialStore)
        AppDelegate.store = initialStore

        SubscriptionManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .modelContainer(container)
                .preferredColorScheme(.light)
                .onAppear {
                    AppDelegate.store = store
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        reconcileScreenTimeState()
                        NotificationManager.shared.requestReschedule(from: store, reason: "app-became-active")
                    } else if newPhase == .background {
                        // Schedule BGAppRefreshTask when going to background
                        AppDelegate.scheduleScreenTimeReconcileTask()
                    }
                }
        }
    }

    private func reconcileScreenTimeState() {
        AppBlockingManager.shared.updateAuthorizationStatus()
        store.syncTodayTakenToAppGroup()
        AppBlockingManager.shared.reconcileBlockingState(
            isTodayTaken: store.isTodayHandled,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
    }
}

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
import os

enum SubscriptionLaunchPolicy {
    static func shouldConfigureRevenueCat(
        isRunningTests: Bool,
        isOnboardingActive: Bool
    ) -> Bool {
        !isRunningTests
    }
}

enum TrialAccessLifecycle {
    enum Event {
        case calendarDayChanged
        case significantTimeChanged
    }

    static func handle(
        _ event: Event,
        refreshAccess: () -> Void,
        reconcileProtection: () -> Void
    ) {
        switch event {
        case .calendarDayChanged, .significantTimeChanged:
            refreshAccess()
            reconcileProtection()
        }
    }

    @discardableResult
    static func handleForeground(
        isOnboardingActive: Bool,
        refreshAccess: () -> Void,
        reconcileProtection: () -> Void
    ) -> Bool {
        refreshAccess()
        reconcileProtection()
        return !isOnboardingActive
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var store: PillStore?
    #if DEBUG
    private var memoryWarningObserver: NSObjectProtocol?
    #endif

    private static let bgTaskID = "com.idrisskone.pillie.screentime-reconcile"
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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

@main
struct PillieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    @State private var store: PillStore
    @State private var languagePreference = AppLanguagePreference()
    @State private var showFirstInterventionConfirmation = false
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// True once the user has progressed through any onboarding step on this
    /// device; false on a genuinely fresh install.
    private static func hasExistingAppState(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: OnboardingFlow.stepStorageKey) != nil
            || defaults.bool(forKey: OnboardingTelemetry.onboardingStartedEmittedKey)
    }

    private static func recordInstallCohortIfNeeded(at date: Date = Date()) {
        let defaults = UserDefaults.standard
        let assignment = TrialInstallCohort.recordAssignment(
            at: date,
            hasExistingAppState: hasExistingAppState(in: defaults),
            store: KeychainTrialGrantStore(),
            fallbackAssignment: TrialInstallCohort.storedAssignment(in: defaults)
        )
        defaults.set(assignment.rawValue, forKey: TrialInstallCohort.assignmentStorageKey)
    }

    init() {
        PillieFontRegistration.registerFontsIfNeeded()

        if !Self.isRunningTests {
            Self.recordInstallCohortIfNeeded()
            HistoryDiscoveryAnnouncement.seedForFreshInstallIfNeeded(
                hasExistingAppState: Self.hasExistingAppState(in: .standard)
            )
        }

        let schema = Schema([PillPack.self, PillDay.self])
        let config: ModelConfiguration
        if Self.isRunningTests {
            config = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            // Default app-support URL for now.
            // Phase 5: switch to shared App Group container URL.
            config = ModelConfiguration(for: PillPack.self, PillDay.self)
        }
        let container = try! ModelContainer(for: schema, configurations: [config])
        self.container = container

        if !Self.isRunningTests {
            DataMigration.migrateFromUserDefaultsIfNeeded(context: container.mainContext)
        }

        let initialStore = PillStore(modelContext: container.mainContext)
        self._store = State(initialValue: initialStore)
        AppDelegate.store = initialStore

        if !Self.isRunningTests {
            AnalyticsManager.shared.configure()
            if !Self.isOnboardingActive {
                // Re-plan reminders immediately when the Plus entitlement flips so
                // Smart Reminders apply on upgrade / drop on churn without waiting for
                // the next natural reschedule (ADR 0004). Set before configure() so the
                // initial entitlement refresh is covered too.
                SubscriptionManager.shared.onEntitlementChange = { _ in
                    guard let store = AppDelegate.store else { return }
                    NotificationManager.shared.requestReschedule(from: store, reason: "entitlement-change")
                }
            }
            if SubscriptionLaunchPolicy.shouldConfigureRevenueCat(
                isRunningTests: Self.isRunningTests,
                isOnboardingActive: Self.isOnboardingActive
            ) {
                // RevenueCat must resolve paid access and issue #257's remote
                // hard-wall switch even while onboarding is active. Otherwise a
                // user who resumes onboarding after trial expiry can reach Home
                // with both commerce states unresolved and bypass the wall.
                SubscriptionManager.shared.configure()
            }
            // For returning users, RevenueCat configuration synchronously applies
            // cached entitlement state first, so `is_plus` is resolved at capture.
            ProductAnalyticsTelemetry.live.appLaunched()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(languagePreference)
                .environment(\.locale, languagePreference.locale)
                .modelContainer(container)
                .preferredColorScheme(.light)
                .alert(
                    PillieLocalization.string("today.intervention.alert.title"),
                    isPresented: $showFirstInterventionConfirmation
                ) {
                    Button(PillieLocalization.string("global.action.ok"), role: .cancel) {}
                } message: {
                    Text(PillieLocalization.string("today.intervention.alert.body"))
                }
                .onAppear {
                    AppDelegate.store = store
                }
                #if DEBUG
                .onOpenURL { url in
                    handleDebugDeepLink(url)
                }
                #endif
                .onChange(of: scenePhase) { _, newPhase in
                    guard !Self.isRunningTests else { return }
                    if newPhase == .active {
                        // Returning to the foreground may cross a day boundary the
                        // NSCalendarDayChanged observer missed while suspended —
                        // refresh the day-relative read model before anything below
                        // (Screen Time reconcile, reminder replan) consumes it.
                        store.refreshDayContextIfNeeded()
                        // A Reverse Trial can expire while suspended (local midnight
                        // after day 14). Re-derive Plus Access before the consumers
                        // below read it — a flip fires onEntitlementChange, and the
                        // Screen Time reconcile drops blocking (ADR 0007: blocking
                        // must never outlive Plus Access).
                        let shouldRunPostOnboardingWork = TrialAccessLifecycle.handleForeground(
                            isOnboardingActive: Self.isOnboardingActive,
                            refreshAccess: {
                                SubscriptionManager.shared.refreshPlusAccess()
                                // First open at-or-after expiry records `trial_expired`
                                // exactly once (#167), after access re-evaluation.
                                recordTrialExpiredIfNeeded()
                            },
                            // A saved onboarding selection can already have applied
                            // shields. Remove them at expiry even if the user remains
                            // on protectionPlanReady; only reminder work stays gated.
                            reconcileProtection: reconcileScreenTimeState
                        )
                        ProductAnalyticsTelemetry.live.appBecameActive()
                        // Shield intercepts accumulated while we weren't running
                        // (#161): flush the App Group delta as one aggregated
                        // blocker_intervention_fired. Before the onboarding guard —
                        // blocking fires for any user whose Protection Plan is live.
                        flushBlockerInterventions()
                        guard shouldRunPostOnboardingWork else { return }
                        NotificationManager.shared.requestReschedule(from: store, reason: "app-became-active")
                    } else if newPhase == .background {
                        // Flush buffered analytics before the app is suspended/killed.
                        // TikTok installs that bounce mid-onboarding otherwise lose their
                        // early funnel events (app_launched, onboarding_started), which
                        // is a major contributor to the ~25% coverage gap (#140).
                        AnalyticsManager.shared.flush()
                        // Schedule BGAppRefreshTask when going to background
                        AppDelegate.scheduleScreenTimeReconcileTask()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    guard !Self.isRunningTests else { return }
                    TrialAccessLifecycle.handle(
                        .calendarDayChanged,
                        refreshAccess: {
                            // A trial can expire while Pillie remains foregrounded
                            // across local midnight. Reconcile immediately so Home's
                            // existing access-change observer presents the hard wall.
                            SubscriptionManager.shared.refreshPlusAccess()
                            recordTrialExpiredIfNeeded()
                        },
                        reconcileProtection: reconcileScreenTimeState
                    )
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.significantTimeChangeNotification
                    )
                ) { _ in
                    guard !Self.isRunningTests else { return }
                    TrialAccessLifecycle.handle(
                        .significantTimeChanged,
                        refreshAccess: {
                            // Clock and time-zone changes can cross the trial's
                            // local-day expiry boundary without changing scene phase.
                            SubscriptionManager.shared.refreshPlusAccess()
                            recordTrialExpiredIfNeeded()
                        },
                        reconcileProtection: reconcileScreenTimeState
                    )
                }
        }
    }

    /// Records `trial_expired` on the first app open at-or-after Reverse Trial
    /// expiry (#167). The decision defers until RevenueCat has resolved
    /// entitlement this launch, so a mid-trial converter is never misread as
    /// expired; the persisted flag makes the event exactly-once.
    private func recordTrialExpiredIfNeeded() {
        let manager = SubscriptionManager.shared
        guard TrialExpiredEvent.shouldFire(
            state: PlusAccessState(
                hasEntitlement: manager.hasEntitlement,
                trialGrantDate: manager.trialGrantDate
            ),
            entitlementResolved: manager.hasResolvedEntitlement,
            alreadyFired: UserDefaults.standard.bool(forKey: TrialExpiredEvent.firedStorageKey),
            calendar: .current,
            now: Date()
        ) else { return }
        ProductAnalyticsTelemetry.live.trialExpired()
        UserDefaults.standard.set(true, forKey: TrialExpiredEvent.firedStorageKey)
    }

    private func flushBlockerInterventions() {
        let count = BlockerInterventionSharedState().flushUnflushed()
        guard count > 0 else { return }
        ProductAnalyticsTelemetry.live.blockerInterventionFired(count: count)

        let manager = SubscriptionManager.shared
        let defaults = UserDefaults.standard
        guard FirstInterventionConfirmation.shouldPresent(
            flushedCount: count,
            state: PlusAccessState(
                hasEntitlement: manager.hasEntitlement,
                trialGrantDate: manager.trialGrantDate
            ),
            alreadyShown: defaults.bool(forKey: FirstInterventionConfirmation.shownStorageKey),
            calendar: .current,
            now: Date()
        ) else { return }

        defaults.set(true, forKey: FirstInterventionConfirmation.shownStorageKey)
        showFirstInterventionConfirmation = true
    }

    private func reconcileScreenTimeState() {
        AppBlockingManager.shared.updateAuthorizationStatus()
        store.syncTodayTakenToAppGroup()
        AppBlockingManager.shared.reconcileBlockingState(
            isTodayHandled: store.isTodayHandled,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
    }

    private static var isOnboardingActive: Bool {
        OnboardingFlow.isOnboardingActive(
            rawStep: UserDefaults.standard.integer(forKey: OnboardingFlow.stepStorageKey)
        )
    }

    #if DEBUG
    private func handleDebugDeepLink(_ url: URL) {
        guard url.scheme == "pillie", url.host == "debug" else { return }

        switch url.path {
        case "/posthog-smoke":
            ProductAnalyticsTelemetry.live.appLaunched(source: .home)
            ProductAnalyticsTelemetry.live.onboardingStarted(step: .welcome)
            ProductAnalyticsTelemetry.live.onboardingStepViewed(.welcome)
            AnalyticsManager.shared.flush()
        case "/error-tracking-smoke":
            // QA control (#179): fire a deliberate handled error so PostHog shows
            // both an `app_error` and a `$exception` for the same failure. Debug
            // builds have no token, so verify via the OSLog analytics mirror.
            let smokeError = NSError(
                domain: "com.idrisskone.pillie.debug-smoke", code: 179,
                userInfo: [NSLocalizedDescriptionKey: "deliberate error-tracking smoke test"]
            )
            ProductAnalyticsTelemetry.live.trackError(
                .debug, error: smokeError, context: ["operation": "smoke"]
            )
            AnalyticsManager.shared.flush()
        case "/plus-app-blocking-setup":
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let forceHardPaywall = queryItems?
                .first(where: { $0.name == "terms" })?.value == "hard"
            if forceHardPaywall {
                let expired = queryItems?
                    .first(where: { $0.name == "expired" })?.value == "1"
                let scenario = OnboardingHardPaywallDebugScenario.make(expired: expired)
                SubscriptionManager.shared.setPlusForTesting(false)
                SubscriptionManager.shared.debugOverrideTrialGrantDate(
                    scenario.grantDate,
                    termsCohort: scenario.termsCohort
                )
                UserDefaults.standard.removeObject(
                    forKey: TrialEndPaywallAutoPresentation.shownStorageKey
                )
            } else {
                SubscriptionManager.shared.setPlusForTesting(true)
            }
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(
                false,
                forKey: "pillie_debug_app_blocking_authorization_recovery"
            )
            UserDefaults.standard.set(OnboardingFlow.Step.appBlocking.rawValue, forKey: OnboardingFlow.stepStorageKey)
        case "/plus-app-blocking-recovery":
            // Simulator FamilyControls authorization auto-approves. This QA-only
            // route renders the same recovery state a real denied/cancelled request
            // reaches, without changing persisted selection or authorization.
            SubscriptionManager.shared.setPlusForTesting(true)
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(
                true,
                forKey: "pillie_debug_app_blocking_authorization_recovery"
            )
            UserDefaults.standard.set(OnboardingFlow.Step.appBlocking.rawValue, forKey: OnboardingFlow.stepStorageKey)
        case "/onboarding-personalization-intent":
            UserDefaults.standard.set(
                OnboardingFlow.Step.painPoints.rawValue,
                forKey: OnboardingFlow.stepStorageKey
            )
        case "/onboarding-personalization-timing":
            UserDefaults.standard.set(
                OnboardingFlow.Step.missFrequency.rawValue,
                forKey: OnboardingFlow.stepStorageKey
            )
        case "/trial-granted-moment":
            // Legacy QA shortcut (#164): the retired step migrates to app-blocking
            // setup (#204), which writes the grant and fires `trial_granted` once.
            SubscriptionManager.shared.setPlusForTesting(false)
            SubscriptionManager.shared.debugOverrideTrialGrantDate(nil)
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(OnboardingFlow.Step.trialGranted.rawValue, forKey: OnboardingFlow.stepStorageKey)
        case "/trial-grant":
            // QA control (#160): start a Reverse Trial now — every Plus feature
            // should unlock exactly as if the entitlement flipped on. A fresh
            // trial also re-opens the one-shot `trial_expired` window (#167) so
            // expiry stays demoable across repeated QA runs. The warning-sent
            // dedupe resets with it so the day-10/13 events re-fire too (#168).
            UserDefaults.standard.removeObject(forKey: TrialExpiredEvent.firedStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialExpiryWarningDelivery.sentDaysStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialEndPaywallAutoPresentation.shownStorageKey)
            SubscriptionManager.shared.grantReverseTrial()
            reconcileScreenTimeState()
        case "/trial-activation-hub":
            // QA seam (#219): FamilyControls selections cannot be made on the
            // simulator, so seed the three acceptance states without changing
            // production behavior. `state` is unconfigured, partial, or full.
            let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "state" })?.value ?? "unconfigured"
            let forceHardPaywall = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "terms" })?.value == "hard"
            let hasBlocking = state == "partial" || state == "full"
            let fullyConfigured = state == "full"

            SubscriptionManager.shared.setPlusForTesting(false)
            if forceHardPaywall {
                let scenario = OnboardingHardPaywallDebugScenario.make(expired: false)
                SubscriptionManager.shared.debugOverrideTrialGrantDate(
                    scenario.grantDate,
                    termsCohort: scenario.termsCohort
                )
            } else {
                SubscriptionManager.shared.debugOverrideTrialGrantDate(Date())
            }
            UserDefaults.standard.removeObject(
                forKey: FirstInterventionConfirmation.shownStorageKey
            )
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(OnboardingFlow.Step.complete.rawValue, forKey: OnboardingFlow.stepStorageKey)

            AppBlockingManager.shared.debugBlockerConfiguredOverride = hasBlocking
            AppBlockingManager.shared.blockingEnabled = hasBlocking

            store.customDueReminderTitle = fullyConfigured ? "My daily reminder" : ""
            store.customDueReminderBody = ""
            store.customRetryReminderTitle = ""
            store.customRetryReminderBody = ""
            store.customLastCallReminderTitle = ""
            store.customLastCallReminderBody = ""
            store.autoReminderIntervalMinutes = fullyConfigured ? 30 : 10
            store.autoReminderRetryLimit = 3
            store.lastCallReminderEnabled = false
            reconcileScreenTimeState()
        case "/trial-age":
            // QA control (#160): age the existing (or a fresh) trial back by
            // ?days=N (default 15, i.e. past the day-14 rollover) so expiry
            // gating is demoable without waiting two weeks.
            let days = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "days" })?.value.flatMap(Int.init) ?? 15
            let baseline = SubscriptionManager.shared.trialGrantDate ?? Date()
            let agedGrant = Calendar.current.date(byAdding: .day, value: -days, to: baseline) ?? baseline
            SubscriptionManager.shared.debugOverrideTrialGrantDate(agedGrant)
            reconcileScreenTimeState()
        case "/trial-clear":
            // QA control (#160): remove the persisted grant entirely, including
            // the one-shot `trial_expired` flag (#167) and the warning-sent
            // dedupe (#168).
            UserDefaults.standard.removeObject(forKey: TrialExpiredEvent.firedStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialExpiryWarningDelivery.sentDaysStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialEndPaywallAutoPresentation.shownStorageKey)
            SubscriptionManager.shared.debugOverrideTrialGrantDate(nil)
            reconcileScreenTimeState()
        case "/plus-home":
            // QA shortcut: land on the onboarded main app as a Plus subscriber so the
            // Plus-gated Settings surfaces (e.g. Reminder Messages) are reachable.
            SubscriptionManager.shared.setPlusForTesting(true)
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(OnboardingFlow.Step.complete.rawValue, forKey: OnboardingFlow.stepStorageKey)
        case "/request-notification-permission":
            // QA control (#168): surface the system notification prompt on
            // installs seeded past onboarding, where the real permission step
            // never ran and scheduling would otherwise be silently dropped.
            NotificationManager.shared.requestAuthorization()
        case "/dump-pending-notifications":
            // QA control (#168): print every pending notification request to
            // OSLog so scheduled reminders/warnings are verifiable on the
            // simulator. Stream with:
            //   log stream --predicate 'subsystem == "com.idrisskone.pillie"' --level debug
            let grantDescription = SubscriptionManager.shared.trialGrantDate?.description ?? "none"
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                os.Logger(subsystem: "com.idrisskone.pillie", category: "qa")
                    .debug("Pillie QA auth status: \(settings.authorizationStatus.rawValue, privacy: .public) trialGrant=\(grantDescription, privacy: .public)")
            }
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let logger = os.Logger(subsystem: "com.idrisskone.pillie", category: "qa")
                logger.debug("Pillie QA pending requests: \(requests.count, privacy: .public)")
                for request in requests.sorted(by: { $0.identifier < $1.identifier }) {
                    let fireDate = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                    logger.debug(
                        "Pillie QA pending: \(request.identifier, privacy: .public) fire=\(fireDate?.description ?? "-", privacy: .public) title=\(request.content.title, privacy: .public)"
                    )
                }
            }
        case "/intervention-seed":
            // QA control (#161): record N shield intercepts exactly as the
            // shield extension does, so the foreground flush is demoable
            // without firing a real shield (simulator Screen Time is not
            // trusted). Background and reopen the app to trigger the flush.
            let count = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "count" })?.value.flatMap(Int.init) ?? 5
            let state = BlockerInterventionSharedState()
            for _ in 0..<max(0, count) { state.recordIntercept() }
        case "/update-trial-announcement":
            // QA shortcut (#165): pre-seed the onboarded-free existing-user state —
            // onboarding complete, no entitlement, no trial grant, update window
            // open. Relaunch the app after opening this link: the next launch
            // grants the trial, fires `trial_granted` (source: update), and shows
            // the one-time announcement sheet.
            SubscriptionManager.shared.setPlusForTesting(false)
            SubscriptionManager.shared.debugOverrideTrialGrantDate(nil)
            UserDefaults.standard.removeObject(forKey: ExistingUserTrialGrant.handledStorageKey)
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(OnboardingFlow.Step.complete.rawValue, forKey: OnboardingFlow.stepStorageKey)
        case "/trial-end-paywall":
            // QA shortcut (#169): land on Home with a trial aged past expiry and
            // the one-shot auto-present window reopened, so the Trial-End
            // Paywall appears on the next Home pass. `?cohort=blocker` forces
            // the blocker-configured (loss-framed) cohort — FamilyControls
            // tokens can never be selected on the simulator; anything else is
            // the reminder-only (gain-framed) cohort. `?terms=hard` applies a
            // deterministic post-cutover expired scenario for pre-cutover QA.
            // Combine with
            // /intervention-seed and /review-prompt-style seeded history for
            // real-looking stats.
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let cohort = queryItems?.first(where: { $0.name == "cohort" })?.value
            let forceHardPaywall = queryItems?.first(where: { $0.name == "terms" })?.value == "hard"
            let feedback = queryItems?.first(where: { $0.name == "feedback" })?.value
            let subscriber = queryItems?.first(where: { $0.name == "subscriber" })?.value == "1"
            AppBlockingManager.shared.debugBlockerConfiguredOverride = (cohort == "blocker")
            let feedbackStore = KeychainTrialDeclineFeedbackResolutionStore()
            if feedback == "resolved" {
                feedbackStore.markResolved()
            } else if feedback == "unresolved" {
                feedbackStore.clearResolution()
            }
            if queryItems?.first(where: { $0.name == "success" })?.value == "1" {
                // Render the post-purchase success state (sandbox purchases are
                // unreachable from simctl launches).
                UserDefaults.standard.set(true, forKey: TrialEndPaywallView.debugSuccessStateKey)
            }
            SubscriptionManager.shared.setPlusForTesting(subscriber)
            let scenario = TrialEndPaywallDebugScenario.make(
                forceHardPaywall: forceHardPaywall
            )
            UserDefaults.standard.removeObject(forKey: TrialEndPaywallAutoPresentation.shownStorageKey)
            UserDefaults.standard.set(false, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(OnboardingFlow.Step.complete.rawValue, forKey: OnboardingFlow.stepStorageKey)
            SubscriptionManager.shared.debugApplyTrialEndPaywallScenario(scenario)
            reconcileScreenTimeState()
        case "/review-prompt":
            // QA shortcut (#133): land on Home with an unbroken Streak past the pill
            // threshold so the Review Prompt's Sentiment Gate card surfaces and the
            // positive tap → Native Review Request can be verified in the simulator.
            SubscriptionManager.shared.setPlusForTesting(false)
            UserDefaults.standard.set(true, forKey: OnboardingFlow.selectedFreePlanStorageKey)
            UserDefaults.standard.set(OnboardingFlow.Step.complete.rawValue, forKey: OnboardingFlow.stepStorageKey)
            store.seedReviewPromptEligibleStreak()
        default:
            return
        }
    }
    #endif
}

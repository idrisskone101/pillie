//
//  AppBlockingManager.swift
//  Pillie
//
//  Orchestrates Screen Time app blocking: authorization, shield management,
//  DeviceActivity scheduling, and FamilyActivitySelection persistence.
//

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import os

@Observable
final class AppBlockingManager {
    static let shared = AppBlockingManager()
    private static let logger = Logger(
        subsystem: "com.idrisskone.pillie",
        category: "AppBlockingManager"
    )

    private(set) var isAuthorized = false
    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    var activitySelection = FamilyActivitySelection() {
        didSet { ScreenTimeSharedState.saveSelection(activitySelection) }
    }

    #if DEBUG
    /// QA seam (#169): FamilyControls tokens can never be selected on the
    /// simulator, so the blocker-configured cohort (Protection Off card,
    /// loss-framed Trial-End Paywall) is unreachable there without this.
    /// Set via `pillie://debug/trial-end-paywall?cohort=blocker`.
    var debugBlockerConfiguredOverride: Bool?
    #endif

    var hasAppsSelected: Bool {
        #if DEBUG
        if let debugBlockerConfiguredOverride { return debugBlockerConfiguredOverride }
        #endif
        return !activitySelection.applicationTokens.isEmpty || !activitySelection.categoryTokens.isEmpty
    }

    var selectedCount: Int {
        activitySelection.applicationTokens.count + activitySelection.categoryTokens.count
    }

    struct RoutineState {
        let isTodayHandled: Bool
        let reminderHour: Int
        let reminderMinute: Int
        let method: ContraceptiveMethod
        let blockingSchedule: BlockingScheduleMirror
    }

    /// Whether blocking is effectively on (enabled + apps selected).
    /// Use this single source of truth across all views.
    var isEffectivelyOn: Bool {
        blockingEnabled && hasAppsSelected
    }

    /// Human-readable summary for display in settings/home.
    var statusSummary: String {
        if !blockingEnabled { return "Off" }
        if !hasAppsSelected { return "No apps" }
        let count = selectedCount
        return blockingActive ? "Active · \(count)" : "On · \(count)"
    }

    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private static let activityName = DeviceActivityName("pillie.reminder.block")

    /// Locally tracked so @Observable fires UI updates.
    /// Kept in sync with ScreenTimeSharedState (App Group defaults).
    private(set) var blockingActive = false
    var blockingEnabled: Bool = true {
        didSet {
            ScreenTimeSharedState.isBlockingEnabled = blockingEnabled
            if !blockingEnabled {
                removeBlocking()
            }
        }
    }

    private init() {
        activitySelection = ScreenTimeSharedState.loadSelection()
        blockingActive = ScreenTimeSharedState.isBlockingRequested
        blockingEnabled = ScreenTimeSharedState.isBlockingEnabled
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    enum AuthorizationStatus {
        case notDetermined, approved, denied
    }

    func requestAuthorization() async {
        #if targetEnvironment(simulator)
        isAuthorized = true
        authorizationStatus = .approved
        return
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationStatus = .approved
        } catch {
            isAuthorized = false
            authorizationStatus = .denied
            Self.logger.error("Screen Time auth error: \(error.localizedDescription)")
            // `warning`, not `error`: this catch also fires when the user declines
            // the system dialog, which is a choice rather than a malfunction.
            ProductAnalyticsTelemetry.live.trackError(
                .screenTime, error: error,
                context: ["operation": "authorization"], severity: .warning
            )
        }
        #endif
    }

    func updateAuthorizationStatus() {
        #if targetEnvironment(simulator)
        isAuthorized = true
        authorizationStatus = .approved
        #else
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess:
            isAuthorized = true
            authorizationStatus = .approved
        case .denied:
            isAuthorized = false
            authorizationStatus = .denied
        case .notDetermined:
            isAuthorized = false
            authorizationStatus = .notDetermined
        @unknown default:
            isAuthorized = false
            authorizationStatus = .notDetermined
        }
        #endif
    }

    // MARK: - Shield Management

    func applyBlocking(reason: String) {
        guard SubscriptionManager.shared.hasPlusAccess else { return }
        guard hasAppsSelected else { return }

        #if !targetEnvironment(simulator)
        store.shield.applications = activitySelection.applicationTokens.isEmpty
            ? nil
            : activitySelection.applicationTokens
        store.shield.applicationCategories = activitySelection.categoryTokens.isEmpty
            ? nil
            : .specific(activitySelection.categoryTokens)
        store.shield.webDomains = activitySelection.webDomainTokens.isEmpty
            ? nil
            : activitySelection.webDomainTokens
        #endif

        ScreenTimeSharedState.isBlockingRequested = true
        ScreenTimeSharedState.blockingReason = reason
        blockingActive = true
    }

    func removeBlocking() {
        #if !targetEnvironment(simulator)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        #endif

        ScreenTimeSharedState.isBlockingRequested = false
        ScreenTimeSharedState.blockingReason = ""
        blockingActive = false
    }

    /// Reconciles blocking state: applies shields after reminder time only when
    /// today's action is still pending, and removes them when today is handled
    /// (completed, passive, or a break day).
    func reconcileBlockingState(
        isTodayHandled: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        method: ContraceptiveMethod
    ) {
        guard SubscriptionManager.shared.hasPlusAccess else {
            if blockingActive { removeBlocking() }
            return
        }
        guard hasAppsSelected, blockingEnabled else {
            if !blockingEnabled { removeBlocking() }
            return
        }

        if isTodayHandled {
            removeBlocking()
            return
        }

        // Check if we're past the reminder time today
        let now = Date()
        let calendar = Calendar.current
        guard let reminderToday = calendar.date(
            bySettingHour: reminderHour,
            minute: reminderMinute,
            second: 0,
            of: now
        ), now >= reminderToday else {
            return
        }

        // Past reminder time + not taken = apply blocking
        applyBlocking(reason: method.blockingReasonText)
    }

    func saveSelectionAndReconcile(routine: RoutineState) {
        saveSelection()
        ScreenTimeSharedState.setBlockingScheduleMirror(routine.blockingSchedule)
        scheduleDeviceActivityBlock(hour: routine.reminderHour, minute: routine.reminderMinute)
        reconcileBlockingState(
            isTodayHandled: routine.isTodayHandled,
            reminderHour: routine.reminderHour,
            reminderMinute: routine.reminderMinute,
            method: routine.method
        )
    }

    func reconcileEnabledBlocking(routine: RoutineState) {
        ScreenTimeSharedState.setBlockingScheduleMirror(routine.blockingSchedule)
        reconcileBlockingState(
            isTodayHandled: routine.isTodayHandled,
            reminderHour: routine.reminderHour,
            reminderMinute: routine.reminderMinute,
            method: routine.method
        )
        scheduleDeviceActivityBlock(hour: routine.reminderHour, minute: routine.reminderMinute)
    }

    // MARK: - DeviceActivity Scheduling

    func scheduleDeviceActivityBlock(hour: Int, minute: Int) {
        guard hasAppsSelected else {
            Self.logger.info("scheduleDeviceActivityBlock: no apps selected, stopping monitoring")
            stopMonitoring()
            return
        }

        #if targetEnvironment(simulator)
        Self.logger.debug("scheduleDeviceActivityBlock: skipped on simulator (hour: \(hour), minute: \(minute))")
        return
        #else
        Self.logger.info("scheduleDeviceActivityBlock: scheduling \(hour):\(minute) → 23:59")

        // Stop existing monitoring before re-scheduling
        center.stopMonitoring([Self.activityName])

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: hour, minute: minute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(Self.activityName, during: schedule)
            Self.logger.info("scheduleDeviceActivityBlock: monitoring started successfully")
        } catch {
            Self.logger.error("scheduleDeviceActivityBlock: failed — \(error.localizedDescription)")
            ProductAnalyticsTelemetry.live.trackError(
                .screenTime, error: error, context: ["operation": "monitoring"]
            )
        }
        #endif
    }

    func stopMonitoring() {
        #if !targetEnvironment(simulator)
        center.stopMonitoring([Self.activityName])
        #endif
    }

    // MARK: - Selection Persistence

    func saveSelection() {
        ScreenTimeSharedState.saveSelection(activitySelection)
    }

    func loadSelection() {
        activitySelection = ScreenTimeSharedState.loadSelection()
    }
}

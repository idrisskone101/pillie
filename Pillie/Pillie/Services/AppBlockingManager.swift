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

    var hasAppsSelected: Bool {
        !activitySelection.applicationTokens.isEmpty || !activitySelection.categoryTokens.isEmpty
    }

    var selectedCount: Int {
        activitySelection.applicationTokens.count + activitySelection.categoryTokens.count
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
        }
        #endif
    }

    func updateAuthorizationStatus() {
        #if targetEnvironment(simulator)
        isAuthorized = true
        authorizationStatus = .approved
        #else
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
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
        guard SubscriptionManager.shared.isPlus else { return }
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

    /// Reconciles blocking state: applies shields if past reminder time and not yet taken,
    /// or removes them if already taken. Call on app launch, foreground return, and after setup.
    func reconcileBlockingState(
        isTodayTaken: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        method: ContraceptiveMethod
    ) {
        guard SubscriptionManager.shared.isPlus else {
            if blockingActive { removeBlocking() }
            return
        }
        guard hasAppsSelected, blockingEnabled else {
            if !blockingEnabled { removeBlocking() }
            return
        }

        if isTodayTaken {
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

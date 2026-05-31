//
//  AnalyticsManager.swift
//  Pillie
//

import Foundation
import PostHog

enum AnalyticsEvent: String {
    case appLaunched = "app_launched"
    case appBecameActive = "app_became_active"
    case onboardingStarted = "onboarding_started"
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingStepCompleted = "onboarding_step_completed"
    case onboardingBackTapped = "onboarding_back_tapped"
    case onboardingCompleted = "onboarding_completed"
    case paywallViewed = "paywall_viewed"
    case paywallPlanSelected = "paywall_plan_selected"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchaseCancelled = "purchase_cancelled"
    case restoreStarted = "restore_started"
    case restoreCompleted = "restore_completed"
    case restoreFailed = "restore_failed"
    case continueFreeSelected = "continue_free_selected"
    case notificationPermissionRequested = "notification_permission_requested"
    case screenTimePermissionRequested = "screen_time_permission_requested"
    case screenTimePermissionCompleted = "screen_time_permission_completed"
    case tabSelected = "tab_selected"
    case settingsSheetOpened = "settings_sheet_opened"
    case settingsChangeSaved = "settings_change_saved"
    case settingsChangeCancelled = "settings_change_cancelled"
    case todayActionStarted = "today_action_started"
    case todayActionCompleted = "today_action_completed"
    case todayActionUndone = "today_action_undone"
    case newPackOrCyclePrompted = "new_pack_or_cycle_prompted"
    case newPackOrCycleStarted = "new_pack_or_cycle_started"
    case plusUpsellViewed = "plus_upsell_viewed"
    case plusUpsellDismissed = "plus_upsell_dismissed"
    case plusUpsellUpgradeTapped = "plus_upsell_upgrade_tapped"
}

enum AnalyticsSource: String {
    case onboarding
    case settings
    case home
    case upsell
}

enum AnalyticsStep: String {
    case welcome
    case painPoints = "pain_points"
    case goal
    case missFrequency = "miss_frequency"
    case freePlan = "free_plan"
    case plusPreview = "plus_preview"
    case paywall
    case method
    case schedule
    case reminderTime = "reminder_time"
    case appBlocking = "app_blocking"

    init?(onboardingStep: Int) {
        switch onboardingStep {
        case 0: self = .welcome
        case 1: self = .painPoints
        case 2: self = .goal
        case 3: self = .missFrequency
        case 4: self = .freePlan
        case 5: self = .plusPreview
        case 6: self = .paywall
        case 7: self = .method
        case 8: self = .schedule
        case 9: self = .reminderTime
        case 10: self = .appBlocking
        default: return nil
        }
    }
}

enum AnalyticsScreen: String {
    case home
    case calendar
    case settings
}

enum AnalyticsPlan: String {
    case annual
    case monthly
}

enum AnalyticsResult: String {
    case granted
    case denied
    case failed
    case cancelled
    case completed
}

enum AnalyticsSetting: String {
    case reminderTime = "reminder_time"
    case autoReminderInterval = "auto_reminder_interval"
    case supplyReminder = "supply_reminder"
    case `protocol`
    case cycleDay = "cycle_day"
    case blockedApps = "blocked_apps"
    case subscription
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    static let analyticsOptOutKey = "pillie_analytics_opt_out"

    private var isConfigured = false
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isAnalyticsEnabled: Bool {
        !defaults.bool(forKey: Self.analyticsOptOutKey)
    }

    func configure() {
        guard !isConfigured else { return }
        guard let projectToken = infoDictionaryString("PostHogProjectToken"), !projectToken.isEmpty else {
            return
        }

        let host = infoDictionaryString("PostHogHost") ?? "https://us.i.posthog.com"
        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.sendFeatureFlagEvent = false
        config.preloadFeatureFlags = false
        config.setDefaultPersonProperties = false
        config.optOut = !isAnalyticsEnabled

        #if os(iOS)
        config.captureElementInteractions = false
        config.sessionReplay = false
        if #available(iOS 15.0, *) {
            config.surveys = false
        }
        #endif

        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        defaults.set(!enabled, forKey: Self.analyticsOptOutKey)
        guard isConfigured else { return }
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource? = nil,
        step: AnalyticsStep? = nil,
        screen: AnalyticsScreen? = nil,
        plan: AnalyticsPlan? = nil,
        result: AnalyticsResult? = nil,
        setting: AnalyticsSetting? = nil,
        isPlus: Bool? = nil,
        hasBlockingSelection: Bool? = nil
    ) {
        guard isConfigured, isAnalyticsEnabled else { return }

        var properties: [String: Any] = [:]
        if let source { properties["source"] = source.rawValue }
        if let step { properties["step"] = step.rawValue }
        if let screen { properties["screen"] = screen.rawValue }
        if let plan { properties["plan"] = plan.rawValue }
        if let result { properties["result"] = result.rawValue }
        if let setting { properties["setting"] = setting.rawValue }
        if let isPlus { properties["is_plus"] = isPlus }
        if let hasBlockingSelection { properties["has_blocking_selection"] = hasBlockingSelection }

        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    private func infoDictionaryString(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}

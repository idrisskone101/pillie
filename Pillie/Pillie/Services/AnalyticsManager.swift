//
//  AnalyticsManager.swift
//  Pillie
//

import Foundation
import PostHog

enum AnalyticsPropertyValue: Equatable {
    case string(String)
    case bool(Bool)

    var postHogValue: Any {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return value
        }
    }
}

struct ProductAnalyticsConfiguration: Equatable {
    let projectToken: String
    let host: String
    let captureApplicationLifecycleEvents: Bool
    let captureScreenViews: Bool
    let captureElementInteractions: Bool
    let enableSwizzling: Bool
    let sendFeatureFlagEvent: Bool
    let preloadFeatureFlags: Bool
    let setDefaultPersonProperties: Bool
    let sessionReplay: Bool
    let surveys: Bool
    let isOptedOut: Bool
}

protocol ProductAnalyticsClient: AnyObject {
    func configure(_ configuration: ProductAnalyticsConfiguration)
    func setOptedOut(_ isOptedOut: Bool)
    func capture(event: String, properties: [String: AnalyticsPropertyValue])
}

final class PostHogAnalyticsClient: ProductAnalyticsClient {
    func configure(_ configuration: ProductAnalyticsConfiguration) {
        let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host)
        config.captureApplicationLifecycleEvents = configuration.captureApplicationLifecycleEvents
        config.captureScreenViews = configuration.captureScreenViews
        config.enableSwizzling = configuration.enableSwizzling
        config.sendFeatureFlagEvent = configuration.sendFeatureFlagEvent
        config.preloadFeatureFlags = configuration.preloadFeatureFlags
        config.setDefaultPersonProperties = configuration.setDefaultPersonProperties
        config.optOut = configuration.isOptedOut

        #if os(iOS)
        config.captureElementInteractions = configuration.captureElementInteractions
        config.sessionReplay = configuration.sessionReplay
        if #available(iOS 15.0, *) {
            config.surveys = configuration.surveys
        }
        #endif

        PostHogSDK.shared.setup(config)
    }

    func setOptedOut(_ isOptedOut: Bool) {
        if isOptedOut {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
        }
    }

    func capture(event: String, properties: [String: AnalyticsPropertyValue]) {
        PostHogSDK.shared.capture(
            event,
            properties: properties.mapValues(\.postHogValue)
        )
    }
}

protocol AnalyticsTracking {
    func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource?,
        step: AnalyticsStep?,
        screen: AnalyticsScreen?,
        plan: AnalyticsPlan?,
        result: AnalyticsResult?,
        setting: AnalyticsSetting?,
        isPlus: Bool?,
        hasBlockingSelection: Bool?
    )
}

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

struct AnalyticsPayload {
    let source: AnalyticsSource?
    let step: AnalyticsStep?
    let screen: AnalyticsScreen?
    let plan: AnalyticsPlan?
    let result: AnalyticsResult?
    let setting: AnalyticsSetting?
    let isPlus: Bool?
    let hasBlockingSelection: Bool?

    init(
        source: AnalyticsSource? = nil,
        step: AnalyticsStep? = nil,
        screen: AnalyticsScreen? = nil,
        plan: AnalyticsPlan? = nil,
        result: AnalyticsResult? = nil,
        setting: AnalyticsSetting? = nil,
        isPlus: Bool? = nil,
        hasBlockingSelection: Bool? = nil
    ) {
        self.source = source
        self.step = step
        self.screen = screen
        self.plan = plan
        self.result = result
        self.setting = setting
        self.isPlus = isPlus
        self.hasBlockingSelection = hasBlockingSelection
    }

    var properties: [String: AnalyticsPropertyValue] {
        var properties: [String: AnalyticsPropertyValue] = [:]
        if let source { properties["source"] = .string(source.rawValue) }
        if let step { properties["step"] = .string(step.rawValue) }
        if let screen { properties["screen"] = .string(screen.rawValue) }
        if let plan { properties["plan"] = .string(plan.rawValue) }
        if let result { properties["result"] = .string(result.rawValue) }
        if let setting { properties["setting"] = .string(setting.rawValue) }
        if let isPlus { properties["is_plus"] = .bool(isPlus) }
        if let hasBlockingSelection { properties["has_blocking_selection"] = .bool(hasBlockingSelection) }
        return properties
    }
}

final class AnalyticsManager: AnalyticsTracking {
    static let shared = AnalyticsManager()
    static let analyticsOptOutKey = "pillie_analytics_opt_out"

    private var isConfigured = false
    private let defaults: UserDefaults
    private let client: ProductAnalyticsClient
    private let infoDictionary: [String: Any]?

    init(
        defaults: UserDefaults = .standard,
        client: ProductAnalyticsClient = PostHogAnalyticsClient(),
        infoDictionary: [String: Any]? = nil
    ) {
        self.defaults = defaults
        self.client = client
        self.infoDictionary = infoDictionary
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
        client.configure(ProductAnalyticsConfiguration(
            projectToken: projectToken,
            host: host,
            captureApplicationLifecycleEvents: false,
            captureScreenViews: false,
            captureElementInteractions: false,
            enableSwizzling: false,
            sendFeatureFlagEvent: false,
            preloadFeatureFlags: false,
            setDefaultPersonProperties: false,
            sessionReplay: false,
            surveys: false,
            isOptedOut: !isAnalyticsEnabled
        ))
        isConfigured = true
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        defaults.set(!enabled, forKey: Self.analyticsOptOutKey)
        guard isConfigured else { return }
        client.setOptedOut(!enabled)
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

        let payload = AnalyticsPayload(
            source: source,
            step: step,
            screen: screen,
            plan: plan,
            result: result,
            setting: setting,
            isPlus: isPlus,
            hasBlockingSelection: hasBlockingSelection
        )
        client.capture(event: event.rawValue, properties: payload.properties)
    }

    private func infoDictionaryString(_ key: String) -> String? {
        let rawValue = infoDictionary?[key] ?? Bundle.main.object(forInfoDictionaryKey: key)
        guard let raw = rawValue as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}

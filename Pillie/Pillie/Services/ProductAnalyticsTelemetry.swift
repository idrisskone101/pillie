//
//  ProductAnalyticsTelemetry.swift
//  Pillie
//

import Foundation

struct ProductAnalyticsTelemetry {
  static let live = ProductAnalyticsTelemetry()

  enum MainTab {
    case today
    case history
    case settings

    var analyticsScreen: AnalyticsScreen {
      switch self {
      case .today: return .home
      case .history: return .calendar
      case .settings: return .settings
      }
    }
  }

  private let analytics: AnalyticsTracking
  private let isPlus: () -> Bool

  init(
    analytics: AnalyticsTracking = AnalyticsManager.shared,
    isPlus: @escaping () -> Bool = { SubscriptionManager.shared.isPlus }
  ) {
    self.analytics = analytics
    self.isPlus = isPlus
  }

  func appLaunched(source: AnalyticsSource? = nil) {
    track(.appLaunched, source: source)
  }

  func appBecameActive() {
    track(.appBecameActive)
  }

  func onboardingStarted(step: AnalyticsStep) {
    track(.onboardingStarted, source: .onboarding, step: step)
  }

  func onboardingStepViewed(_ step: AnalyticsStep) {
    track(.onboardingStepViewed, source: .onboarding, step: step)
  }

  func onboardingStepCompleted(_ step: AnalyticsStep) {
    track(.onboardingStepCompleted, source: .onboarding, step: step)
  }

  func onboardingBackTapped(_ step: AnalyticsStep) {
    track(.onboardingBackTapped, source: .onboarding, step: step)
  }

  func onboardingCompleted() {
    track(.onboardingCompleted, source: .onboarding)
  }

  func onboardingAcquisitionSourceCompleted(_ source: AcquisitionSource) {
    track(
      .onboardingStepCompleted,
      source: .onboarding,
      step: .acquisitionSource,
      acquisitionSource: source
    )
  }

  func notificationPermissionRequested() {
    track(.notificationPermissionRequested, source: .onboarding, step: .reminderTime)
  }

  func screenTimePermissionRequested() {
    track(.screenTimePermissionRequested, source: .onboarding, step: .appBlocking)
  }

  func screenTimePermissionCompleted(isAuthorized: Bool) {
    track(
      .screenTimePermissionCompleted,
      source: .onboarding,
      step: .appBlocking,
      result: isAuthorized ? .granted : .denied
    )
  }

  func onboardingBlockedAppsSaved(hasSelection: Bool) {
    track(
      .settingsChangeSaved,
      source: .onboarding,
      step: .appBlocking,
      setting: .blockedApps,
      hasBlockingSelection: hasSelection
    )
  }

  func paywallViewed(isFromOnboarding: Bool) {
    track(
      .paywallViewed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      step: isFromOnboarding ? .paywall : nil
    )
  }

  func paywallPlanSelected(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(.paywallPlanSelected, source: paywallSource(isFromOnboarding: isFromOnboarding), plan: plan)
  }

  func purchaseStarted(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(.purchaseStarted, source: paywallSource(isFromOnboarding: isFromOnboarding), plan: plan)
  }

  func purchaseCompleted(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(
      .purchaseCompleted,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      plan: plan,
      result: .completed
    )
  }

  func purchaseFailed(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(
      .purchaseFailed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      plan: plan,
      result: .failed
    )
  }

  func purchaseCancelled(plan: AnalyticsPlan, isFromOnboarding: Bool) {
    track(
      .purchaseCancelled,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      plan: plan,
      result: .cancelled
    )
  }

  func restoreStarted(isFromOnboarding: Bool) {
    track(.restoreStarted, source: paywallSource(isFromOnboarding: isFromOnboarding))
  }

  func restoreCompleted(isFromOnboarding: Bool) {
    track(
      .restoreCompleted,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      result: .completed
    )
  }

  func restoreFailed(isFromOnboarding: Bool) {
    track(
      .restoreFailed,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      result: .failed
    )
  }

  func continueFreeSelected(isFromOnboarding: Bool) {
    track(
      .continueFreeSelected,
      source: paywallSource(isFromOnboarding: isFromOnboarding),
      step: isFromOnboarding ? .paywall : nil
    )
  }

  func plusUpsellViewed() {
    track(.plusUpsellViewed, source: .upsell)
  }

  func settingsBlockingUpsellViewed() {
    track(.plusUpsellViewed, source: .settings)
  }

  func plusUpsellDismissed() {
    track(.plusUpsellDismissed, source: .upsell)
  }

  func plusUpsellUpgradeTapped() {
    track(.plusUpsellUpgradeTapped, source: .upsell)
  }

  func upsellRestoreStarted() {
    track(.restoreStarted, source: .upsell)
  }

  func upsellRestoreCompleted() {
    track(.restoreCompleted, source: .upsell, result: .completed)
  }

  func upsellRestoreFailed() {
    track(.restoreFailed, source: .upsell, result: .failed)
  }

  func mainTabSelected(_ tab: MainTab) {
    track(.tabSelected, screen: tab.analyticsScreen)
  }

  func protocolSettingsOpened() {
    settingsSheetOpened(.protocol)
  }

  func reminderTimeSettingsOpened() {
    settingsSheetOpened(.reminderTime)
  }

  func autoReminderIntervalSettingsOpened() {
    settingsSheetOpened(.autoReminderInterval)
  }

  func autoReminderRetryLimitSettingsOpened() {
    settingsSheetOpened(.autoReminderRetryLimit)
  }

  func supplyReminderSettingsOpened() {
    settingsSheetOpened(.supplyReminder)
  }

  func cycleDaySettingsOpened() {
    settingsSheetOpened(.cycleDay)
  }

  func blockedAppsSettingsOpened(hasSelection: Bool) {
    settingsSheetOpened(.blockedApps, hasBlockingSelection: hasSelection)
  }

  func subscriptionSettingsOpened() {
    settingsSheetOpened(.subscription)
  }

  func protocolChangeSaved() {
    settingsChangeSaved(.protocol)
  }

  func protocolChangeCancelled() {
    track(.settingsChangeCancelled, source: .settings, setting: .protocol)
  }

  func reminderTimeSaved() {
    settingsChangeSaved(.reminderTime)
  }

  func autoReminderIntervalSaved() {
    settingsChangeSaved(.autoReminderInterval)
  }

  func autoReminderRetryLimitSaved() {
    settingsChangeSaved(.autoReminderRetryLimit)
  }

  func supplyReminderSaved() {
    settingsChangeSaved(.supplyReminder)
  }

  func cycleDaySaved() {
    settingsChangeSaved(.cycleDay)
  }

  func blockedAppsSaved(hasSelection: Bool) {
    settingsChangeSaved(.blockedApps, hasBlockingSelection: hasSelection)
  }

  func todayActionStarted() {
    track(.todayActionStarted, source: .home)
  }

  func todayActionCompleted() {
    track(.todayActionCompleted, source: .home)
  }

  func todayActionUndone() {
    track(.todayActionUndone, source: .home)
  }

  func newPackOrCyclePrompted() {
    track(.newPackOrCyclePrompted, source: .home)
  }

  func newPackOrCycleStarted() {
    track(.newPackOrCycleStarted, source: .home)
  }

  private func paywallSource(isFromOnboarding: Bool) -> AnalyticsSource {
    isFromOnboarding ? .onboarding : .settings
  }

  private func settingsSheetOpened(_ setting: AnalyticsSetting, hasBlockingSelection: Bool? = nil) {
    track(
      .settingsSheetOpened,
      source: .settings,
      setting: setting,
      hasBlockingSelection: hasBlockingSelection
    )
  }

  private func settingsChangeSaved(_ setting: AnalyticsSetting, hasBlockingSelection: Bool? = nil) {
    track(
      .settingsChangeSaved,
      source: .settings,
      setting: setting,
      hasBlockingSelection: hasBlockingSelection
    )
  }

  private func track(
    _ event: AnalyticsEvent,
    source: AnalyticsSource? = nil,
    step: AnalyticsStep? = nil,
    screen: AnalyticsScreen? = nil,
    plan: AnalyticsPlan? = nil,
    result: AnalyticsResult? = nil,
    setting: AnalyticsSetting? = nil,
    acquisitionSource: AcquisitionSource? = nil,
    hasBlockingSelection: Bool? = nil
  ) {
    analytics.track(
      event,
      source: source,
      step: step,
      screen: screen,
      plan: plan,
      result: result,
      setting: setting,
      acquisitionSource: acquisitionSource,
      isPlus: isPlus(),
      hasBlockingSelection: hasBlockingSelection
    )
  }
}

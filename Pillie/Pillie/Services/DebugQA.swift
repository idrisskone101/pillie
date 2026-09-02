#if DEBUG
import Foundation

/// Simulator-only QA catalog. Never compiled into release.
enum DebugQASection: String, CaseIterable, Identifiable {
    case pack
    case trialNewUser
    case trialGrandfather
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pack: return "Pack & calendar"
        case .trialNewUser: return "Trial — new users"
        case .trialGrandfather: return "Trial — grandfathered"
        case .other: return "Other"
        }
    }
}

enum DebugQAScenario: String, CaseIterable, Identifiable {
    case missedRecentDays
    case packComplete
    case marketingCalendar
    case trialActive
    case trialLastDay
    case trialExpiredNewUserBlocker
    case trialExpiredNewUserReminder
    case trialExpiredNewUserSuccess
    case trialExpiredNewUserRollback
    case trialExpiredGrandfatherBlocker
    case trialExpiredGrandfatherReminder
    case plusSubscriber
    case existingUserTrialAnnouncement
    case reviewPrompt
    case clearTrial

    var id: String { rawValue }

    var section: DebugQASection {
        switch self {
        case .missedRecentDays, .packComplete, .marketingCalendar:
            return .pack
        case .trialActive, .trialLastDay, .trialExpiredNewUserBlocker,
             .trialExpiredNewUserReminder, .trialExpiredNewUserSuccess,
             .trialExpiredNewUserRollback:
            return .trialNewUser
        case .trialExpiredGrandfatherBlocker, .trialExpiredGrandfatherReminder:
            return .trialGrandfather
        case .plusSubscriber, .existingUserTrialAnnouncement, .reviewPrompt, .clearTrial:
            return .other
        }
    }

    var title: String {
        switch self {
        case .missedRecentDays: return "Missed the last 2 days"
        case .packComplete: return "Pack finished — start a new pack"
        case .marketingCalendar: return "Marketing calendar (mixed usage)"
        case .trialActive: return "Active Reverse Trial (day 3)"
        case .trialLastDay: return "Last day of trial"
        case .trialExpiredNewUserBlocker: return "Expired hard paywall (blocker)"
        case .trialExpiredNewUserReminder: return "Expired hard paywall (reminders)"
        case .trialExpiredNewUserSuccess: return "Expired hard paywall — purchased"
        case .trialExpiredNewUserRollback: return "Expired legacy rollback (kill switch off)"
        case .trialExpiredGrandfatherBlocker: return "Expired dismissible paywall (blocker)"
        case .trialExpiredGrandfatherReminder: return "Expired dismissible paywall (reminders)"
        case .plusSubscriber: return "Plus subscriber home"
        case .existingUserTrialAnnouncement: return "Existing-user trial announcement"
        case .reviewPrompt: return "Review prompt card"
        case .clearTrial: return "Clear trial grant"
        }
    }

    var detail: String {
        switch self {
        case .missedRecentDays:
            return "10-day pack history, last two due days missed."
        case .packComplete:
            return "21/7 pack fully elapsed so Home shows Start New Pack."
        case .marketingCalendar:
            return "Realistic taken/missed mix for screenshots."
        case .trialActive:
            return "Onboarded new-user cohort, 12 days left."
        case .trialLastDay:
            return "Onboarded new-user cohort, expires tonight."
        case .trialExpiredNewUserBlocker:
            return "Post-cutover hard wall, loss-framed blocker stats."
        case .trialExpiredNewUserReminder:
            return "Post-cutover hard wall, reminder-only offer."
        case .trialExpiredNewUserSuccess:
            return "Hard wall success state after a sandbox purchase."
        case .trialExpiredNewUserRollback:
            return "Post-cutover install with hard paywall remotely disabled."
        case .trialExpiredGrandfatherBlocker:
            return "Pre-cutover terms, dismissible loss-framed sheet."
        case .trialExpiredGrandfatherReminder:
            return "Pre-cutover terms, dismissible reminder-only sheet."
        case .plusSubscriber:
            return "Paid Plus, onboarding complete."
        case .existingUserTrialAnnouncement:
            return "Onboarded free user, no grant — relaunch to announce."
        case .reviewPrompt:
            return "Unbroken streak so the Home review card appears."
        case .clearTrial:
            return "Remove Keychain grant and expiry flags."
        }
    }

    static func scenarios(in section: DebugQASection) -> [DebugQAScenario] {
        allCases.filter { $0.section == section }
    }
}

/// Pure description of a DEBUG pack seed. Index 0 is the pack start date;
/// `pastStatuses.count` equals `startDaysAgo`.
struct DebugPackHistoryPlan: Equatable {
    let startDaysAgo: Int
    let pastStatuses: [PillDay.Status]

    static func missedRecentDays(historyDays: Int = 10, missedCount: Int = 2) -> DebugPackHistoryPlan {
        let count = max(missedCount, historyDays)
        var statuses = Array(repeating: PillDay.Status.taken, count: count)
        let miss = min(missedCount, count)
        if miss > 0 {
            for index in (count - miss)..<count {
                statuses[index] = .missed
            }
        }
        return DebugPackHistoryPlan(startDaysAgo: count, pastStatuses: statuses)
    }

    static func completedTwentyOneSevenPack() -> DebugPackHistoryPlan {
        let cycleLength = PillPack.PillRegimenPreset.twentyOneSeven.cycleLength
        let activeDays = PillPack.PillRegimenPreset.twentyOneSeven.activeDays
        let statuses: [PillDay.Status] = (0..<cycleLength).map { offset in
            offset < activeDays ? .taken : .breakDay
        }
        return DebugPackHistoryPlan(startDaysAgo: cycleLength, pastStatuses: statuses)
    }

    static func marketingScreenshot() -> DebugPackHistoryPlan {
        // 18 days of a 21/7 pack: mostly taken, a couple of isolated misses,
        // and one two-day slip so History looks lived-in rather than perfect.
        let pattern: [PillDay.Status] = [
            .taken, .taken, .taken, .missed, .taken,
            .taken, .taken, .taken, .taken, .missed, .missed,
            .taken, .taken, .taken, .missed, .taken,
            .taken, .taken
        ]
        return DebugPackHistoryPlan(startDaysAgo: pattern.count, pastStatuses: pattern)
    }
}

enum DebugQA {
    static func apply(_ scenario: DebugQAScenario, store: PillStore) {
        switch scenario {
        case .missedRecentDays:
            completeOnboarding()
            store.replacePack(with: .missedRecentDays())
        case .packComplete:
            completeOnboarding()
            store.replacePack(with: .completedTwentyOneSevenPack())
        case .marketingCalendar:
            completeOnboarding()
            store.replacePack(with: .marketingScreenshot())
        case .trialActive:
            applyTrial(
                store: store,
                daysAgo: 2,
                cohort: .postCutover,
                hardPaywallEnabled: true,
                blockerConfigured: true,
                subscriber: false
            )
        case .trialLastDay:
            applyTrial(
                store: store,
                daysAgo: ReverseTrialClock.fullDays,
                cohort: .postCutover,
                hardPaywallEnabled: true,
                blockerConfigured: true,
                subscriber: false
            )
        case .trialExpiredNewUserBlocker:
            applyExpiredPaywall(
                store: store,
                cohort: .postCutover,
                hardPaywallEnabled: true,
                blockerConfigured: true,
                success: false
            )
        case .trialExpiredNewUserReminder:
            applyExpiredPaywall(
                store: store,
                cohort: .postCutover,
                hardPaywallEnabled: true,
                blockerConfigured: false,
                success: false
            )
        case .trialExpiredNewUserSuccess:
            applyExpiredPaywall(
                store: store,
                cohort: .postCutover,
                hardPaywallEnabled: true,
                blockerConfigured: true,
                success: true
            )
        case .trialExpiredNewUserRollback:
            applyExpiredPaywall(
                store: store,
                cohort: .postCutover,
                hardPaywallEnabled: false,
                blockerConfigured: true,
                success: false
            )
        case .trialExpiredGrandfatherBlocker:
            applyExpiredPaywall(
                store: store,
                cohort: .preCutover,
                hardPaywallEnabled: true,
                blockerConfigured: true,
                success: false
            )
        case .trialExpiredGrandfatherReminder:
            applyExpiredPaywall(
                store: store,
                cohort: .preCutover,
                hardPaywallEnabled: true,
                blockerConfigured: false,
                success: false
            )
        case .plusSubscriber:
            completeOnboarding()
            persistInstallCohort(.postCutover)
            SubscriptionManager.shared.debugSetHardPaywallEnabled(nil)
            SubscriptionManager.shared.setPlusForTesting(true)
            SubscriptionManager.shared.debugOverrideTrialGrantDate(nil)
            AppBlockingManager.shared.debugBlockerConfiguredOverride = nil
        case .existingUserTrialAnnouncement:
            completeOnboarding()
            persistInstallCohort(.preCutover)
            SubscriptionManager.shared.setPlusForTesting(false)
            SubscriptionManager.shared.debugOverrideTrialGrantDate(nil)
            UserDefaults.standard.removeObject(forKey: ExistingUserTrialGrant.handledStorageKey)
            AppBlockingManager.shared.debugBlockerConfiguredOverride = nil
        case .reviewPrompt:
            completeOnboarding(selectedFreePlan: true)
            SubscriptionManager.shared.setPlusForTesting(false)
            store.seedReviewPromptEligibleStreak()
        case .clearTrial:
            UserDefaults.standard.removeObject(forKey: TrialExpiredEvent.firedStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialExpiryWarningDelivery.sentDaysStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialEndPaywallAutoPresentation.shownStorageKey)
            UserDefaults.standard.removeObject(forKey: TrialEndPaywallView.debugSuccessStateKey)
            SubscriptionManager.shared.debugOverrideTrialGrantDate(nil)
            SubscriptionManager.shared.debugSetHardPaywallEnabled(nil)
        }

        reconcile(store: store)
        NotificationCenter.default.post(name: .pillieDebugQADidApply, object: scenario)
    }

    private static func completeOnboarding(selectedFreePlan: Bool = false) {
        UserDefaults.standard.set(
            OnboardingFlow.Step.complete.rawValue,
            forKey: OnboardingFlow.stepStorageKey
        )
        UserDefaults.standard.set(
            selectedFreePlan,
            forKey: OnboardingFlow.selectedFreePlanStorageKey
        )
    }

    private static func resetTrialPresentationFlags() {
        UserDefaults.standard.removeObject(forKey: TrialExpiredEvent.firedStorageKey)
        UserDefaults.standard.removeObject(forKey: TrialExpiryWarningDelivery.sentDaysStorageKey)
        UserDefaults.standard.removeObject(forKey: TrialEndPaywallAutoPresentation.shownStorageKey)
        UserDefaults.standard.removeObject(forKey: TrialEndPaywallAutoPresentation.rollbackShownStorageKey)
        UserDefaults.standard.removeObject(forKey: TrialEndPaywallView.debugSuccessStateKey)
    }

    private static func persistInstallCohort(_ cohort: TrialTermsCohort) {
        UserDefaults.standard.set(
            cohort.rawValue,
            forKey: TrialInstallCohort.assignmentStorageKey
        )
    }

    private static func seedInterventionStats(blockerConfigured: Bool) {
        guard let defaults = AppGroupConstants.sharedDefaults else { return }
        defaults.set(0, forKey: AppGroupKeys.interventionUnflushedCount)
        defaults.set(
            blockerConfigured ? 7 : 0,
            forKey: AppGroupKeys.interventionLifetimeTotal
        )
        defaults.synchronize()
    }

    private static func applyTrial(
        store: PillStore,
        daysAgo: Int,
        cohort: TrialTermsCohort,
        hardPaywallEnabled: Bool,
        blockerConfigured: Bool,
        subscriber: Bool
    ) {
        completeOnboarding()
        persistInstallCohort(cohort)
        store.replacePack(with: .marketingScreenshot())
        resetTrialPresentationFlags()
        seedInterventionStats(blockerConfigured: blockerConfigured)
        SubscriptionManager.shared.setPlusForTesting(subscriber)
        SubscriptionManager.shared.debugSetHardPaywallEnabled(hardPaywallEnabled)
        let grant = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        SubscriptionManager.shared.debugOverrideTrialGrantDate(grant, termsCohort: cohort)
        AppBlockingManager.shared.debugBlockerConfiguredOverride = blockerConfigured
        AppBlockingManager.shared.blockingEnabled = blockerConfigured
    }

    private static func applyExpiredPaywall(
        store: PillStore,
        cohort: TrialTermsCohort,
        hardPaywallEnabled: Bool,
        blockerConfigured: Bool,
        success: Bool
    ) {
        completeOnboarding()
        persistInstallCohort(cohort)
        store.replacePack(with: .marketingScreenshot())
        resetTrialPresentationFlags()
        seedInterventionStats(blockerConfigured: blockerConfigured)
        SubscriptionManager.shared.setPlusForTesting(false)
        SubscriptionManager.shared.debugSetHardPaywallEnabled(hardPaywallEnabled)
        SubscriptionManager.shared.debugApplyTrialEndPaywallScenario(
            .expired(termsCohort: cohort)
        )
        AppBlockingManager.shared.debugBlockerConfiguredOverride = blockerConfigured
        AppBlockingManager.shared.blockingEnabled = blockerConfigured
        if success {
            UserDefaults.standard.set(true, forKey: TrialEndPaywallView.debugSuccessStateKey)
        }
    }

    private static func reconcile(store: PillStore) {
        AppBlockingManager.shared.updateAuthorizationStatus()
        store.syncTodayTakenToAppGroup()
        AppBlockingManager.shared.reconcileBlockingState(
            isTodayHandled: store.isTodayHandled,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
    }
}

extension Notification.Name {
    static let pillieDebugQADidApply = Notification.Name("pillieDebugQADidApply")
}
#endif

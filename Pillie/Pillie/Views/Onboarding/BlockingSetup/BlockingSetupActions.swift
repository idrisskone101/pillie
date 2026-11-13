//
//  BlockingSetupActions.swift
//  Pillie
//
//  The two things the blocking step does to the system. The view calls them,
//  `BlockingRehearsalState` decides when.
//

import Foundation

struct BlockingSetupActions {
    private let telemetry = OnboardingTelemetry()

    /// Already authorized: returns `.granted` at once and reports nothing.
    /// It does not guard against overlapping calls.
    /// `BlockingRehearsalState.isRequesting` does.
    func authorize() async -> ScreenTimeAuthorizationOutcome {
        let manager = AppBlockingManager.shared
        if manager.isAuthorized { return .granted }
        telemetry.screenTimePermissionRequested()
        await manager.requestAuthorization()
        telemetry.screenTimePermissionCompleted(isAuthorized: manager.isAuthorized)
        return manager.isAuthorized ? .granted : .refused(manager.refusal ?? .notAllowed)
    }

    /// Saves the picked selection and reschedules. False when there is nothing
    /// to save.
    func saveSelection(store: PillStore) -> Bool {
        let manager = AppBlockingManager.shared
        guard manager.selectionState.canSaveBlockerConfig else { return false }
        manager.saveSelectionAndReconcile(
            routine: AppBlockingManager.RoutineState(
                isTodayHandled: store.isTodayHandled,
                liveDay: store.today,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                method: store.pack.method,
                blockingSchedule: store.blockingScheduleMirror
            )
        )
        ScheduleCriticalSettingChange.blockerSetupChanged(store: store)
        ProductAnalyticsTelemetry.live.onboardingBlockerConfigSaved(
            hasSelection: manager.hasAppsSelected
        )
        return true
    }
}

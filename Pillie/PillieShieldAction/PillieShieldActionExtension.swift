//
//  PillieShieldActionExtension.swift
//  PillieShieldAction
//
//  Handles button taps on the shield.
//

import DeviceActivity
import Foundation
import ManagedSettings
import ManagedSettingsUI

class PillieShieldActionExtension: ShieldActionDelegate {
    private static let snoozeResumeActivityName = DeviceActivityName("pillie.blocking.snooze.resume")

    override nonisolated func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override nonisolated func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override nonisolated func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    private nonisolated func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            return .close
        case .secondaryButtonPressed:
            return performBlockingSnooze()
        @unknown default:
            return .close
        }
    }

    private nonisolated func performBlockingSnooze() -> ShieldActionResponse {
        guard let dueDayEpoch = BlockingSnoozeAppGroup.dueDayEpoch else {
            return .none
        }
        let outcome = BlockingSnoozePolicy.attempt(
            ledger: BlockingSnoozeAppGroup.ledger,
            dueDayEpoch: dueDayEpoch,
            now: Date(),
            intervalMinutes: BlockingSnoozeAppGroup.intervalMinutes
        )
        switch outcome.result {
        case .accepted(let until, _):
            BlockingSnoozeAppGroup.ledger = outcome.ledger
            BlockingSnoozeAppGroup.until = until
            clearShields()
            scheduleSnoozeResume(at: until)
            return .close
        case .rejected:
            return .none
        }
    }

    private nonisolated func clearShields() {
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        BlockingSnoozeAppGroup.isBlockingRequested = false
    }

    private nonisolated func scheduleSnoozeResume(at until: Date) {
        #if targetEnvironment(simulator)
        return
        #else
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: until)
        let center = DeviceActivityCenter()
        center.stopMonitoring([Self.snoozeResumeActivityName])
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: components.hour, minute: components.minute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )
        try? center.startMonitoring(Self.snoozeResumeActivityName, during: schedule)
        #endif
    }
}

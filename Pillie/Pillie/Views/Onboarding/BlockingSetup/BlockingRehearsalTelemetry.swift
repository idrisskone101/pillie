//
//  BlockingRehearsalTelemetry.swift
//  Pillie
//
//  Turns the state's signals into analytics events. The stage rides the
//  existing `step`, a real shake rides the existing `shake_count`, and who
//  played a beat is in the event name.
//
//  | Signal                           | Event                               | step              | shake_count |
//  |----------------------------------|-------------------------------------|-------------------|-------------|
//  | .viewed(stage)                   | blocking_rehearsal_stage_viewed     | rehearsal_<stage> |             |
//  | .played(beat, by: .herTap)       | blocking_rehearsal_beat_played      | rehearsal_<beat>  | 0 on shake  |
//  | .played(.shake, by: .herShake)   | blocking_rehearsal_beat_played      | rehearsal_shake   | 1           |
//  | .played(beat, by: .demo)         | blocking_rehearsal_beat_self_played | rehearsal_<beat>  |             |
//  | .refusalAnswered(.askAgain)      | blocking_rehearsal_ask_again        | rehearsal_refused |             |
//  | .refusalAnswered(.remindersOnly) | blocking_rehearsal_reminders_only   | rehearsal_refused |             |
//

import Foundation

struct BlockingRehearsalTelemetry {
    private let telemetry: ProductAnalyticsTelemetry

    init(
        analytics: AnalyticsTracking = AnalyticsManager.shared,
        isPlus: @escaping () -> Bool = { SubscriptionManager.shared.hasEntitlement }
    ) {
        self.telemetry = ProductAnalyticsTelemetry(analytics: analytics, isPlus: isPlus)
    }

    func record(_ signal: BlockingRehearsalSignal) {
        switch signal {
        case .viewed(let stage):
            telemetry.blockingRehearsal(.blockingRehearsalStageViewed, step: stage.analyticsStep)
        case .played(let beat, by: .demo):
            telemetry.blockingRehearsal(.blockingRehearsalBeatSelfPlayed, step: beat.analyticsStep)
        case .played(.shake, by: let player):
            telemetry.blockingRehearsal(
                .blockingRehearsalBeatPlayed,
                step: .rehearsalShake,
                shakeCount: player == .herShake ? 1 : 0
            )
        case .played(let beat, by: _):
            telemetry.blockingRehearsal(.blockingRehearsalBeatPlayed, step: beat.analyticsStep)
        case .refusalAnswered(.askAgain):
            telemetry.blockingRehearsal(.blockingRehearsalAskAgain, step: .rehearsalRefused)
        case .refusalAnswered(.remindersOnly):
            telemetry.blockingRehearsal(.blockingRehearsalRemindersOnly, step: .rehearsalRefused)
        }
    }
}

extension BlockingRehearsalStage {
    var analyticsStep: AnalyticsStep {
        switch self {
        case .reminder: .rehearsalReminder
        case .paused: .rehearsalPaused
        case .shake: .rehearsalShake
        case .ask: .rehearsalAsk
        case .refused: .rehearsalRefused
        case .picks: .rehearsalPicks
        }
    }
}

extension BlockingRehearsalBeat {
    var analyticsStep: AnalyticsStep {
        switch self {
        case .reminder: .rehearsalReminder
        case .paused: .rehearsalPaused
        case .shake: .rehearsalShake
        }
    }
}

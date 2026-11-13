//
//  BlockingRehearsalTelemetry.swift
//  Pillie
//
//  Turns the state's signals into analytics events.
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
        case .askedAgain:
            telemetry.blockingRehearsal(.blockingRehearsalAskAgain, step: .rehearsalRefused)
        case .choseRemindersOnly(on: let stage):
            telemetry.blockingRehearsal(.blockingRehearsalRemindersOnly, step: stage.analyticsStep)
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

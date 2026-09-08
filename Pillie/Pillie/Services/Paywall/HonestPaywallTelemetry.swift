//
//  HonestPaywallTelemetry.swift
//  Pillie
//

import Foundation

enum HonestPaywallTelemetryMode: Equatable {
    case trialEnd(TrialEndPaywallContent)
    case surface
}

enum HonestPaywallTelemetry {
    /// Trial-end events only fire for the C2 board. An expired grant on C1/C3
    /// still uses surface-scoped paywall events.
    static func mode(
        board: HonestPaywallBoard,
        trialEndContent: TrialEndPaywallContent?
    ) -> HonestPaywallTelemetryMode {
        if case .trialEnded = board, let trialEndContent {
            return .trialEnd(trialEndContent)
        }
        return .surface
    }
}

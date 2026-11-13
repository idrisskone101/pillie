//
//  BlockingSetupAccess.swift
//  Pillie
//
//  Which of the blocking step's three screens `ContentView` shows. Access
//  decides it: someone who cannot set blocking up sees no rehearsal.
//

import Foundation

enum BlockingSetupAccess: Equatable {
    /// Entitlement or paywall configuration is still loading.
    case verifying
    /// No Plus access, or she chose the free plan.
    case locked
    case open

    static func resolve(
        activation: OnboardingTrialActivationRoute,
        hasPlusAccess: Bool,
        trialGranted: Bool,
        selectedFreePlan: Bool
    ) -> BlockingSetupAccess {
        if activation == .verifyingAccess { return .verifying }
        if selectedFreePlan { return .locked }
        if hasPlusAccess { return .open }
        // The step's own `onAppear` writes the reverse trial grant, so a fresh
        // install has no access for one frame. Only a grant that already ran
        // out is locked. Otherwise the screen would swap after that frame.
        return trialGranted ? .locked : .open
    }
}

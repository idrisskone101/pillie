//
//  FirstInterventionConfirmation.swift
//  Pillie
//
//  One-time active-trial confirmation after the shield extension's first
//  nonzero intervention flush (issue #220). Pure gating keeps zero counts,
//  expired trials, and subscribers out of the active-trial surface.
//

import Foundation

enum FirstInterventionConfirmation {
    static let shownStorageKey = "firstInterventionConfirmationShown"

    static func shouldPresent(
        flushedCount: Int,
        state: PlusAccessState,
        alreadyShown: Bool,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        flushedCount > 0
            && !alreadyShown
            && !state.hasEntitlement
            && state.trialActive(calendar: calendar, now: now)
    }
}

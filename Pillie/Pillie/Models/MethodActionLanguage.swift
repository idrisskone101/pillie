//
//  MethodActionLanguage.swift
//  Pillie
//
//  Method-aware "Due Action Time" phrasing for the Protection Plan Onboarding flow
//  (PRD #72 / issue #77). Broad brand copy can say "pill time" before the method is
//  known, but once the user picks Pill, Patch, or Ring, Routine Basics and the
//  plan-builder card use these fragments so a Patch or Ring user never sees their
//  routine described in pill terms.
//
//  A pure value type so the method-aware copy is deterministic and unit-testable
//  without driving any SwiftUI view.
//

import Foundation

struct MethodActionLanguage: Equatable {
    let method: ContraceptiveMethod

    /// Short label for the recurring moment Pillie protects, e.g. "pill time".
    var momentLabel: String {
        switch method {
        case .pill: return "pill time"
        case .patch: return "patch day"
        case .ring: return "ring day"
        }
    }

    /// The imperative the user performs to check in, e.g. "take your pill".
    var actionPhrase: String {
        switch method {
        case .pill: return "take your pill"
        case .patch: return "change your patch"
        case .ring: return "check your ring"
        }
    }

    /// Object noun for plan-card / summary copy, e.g. "your pill".
    var objectNoun: String {
        switch method {
        case .pill: return "your pill"
        case .patch: return "your patch"
        case .ring: return "your ring"
        }
    }
}

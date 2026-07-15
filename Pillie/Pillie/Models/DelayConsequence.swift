//
//  DelayConsequence.swift
//  Pillie
//
//  A committed Protection Plan Onboarding answer (PRD #72, issue #75): what
//  missing or delaying a dose usually *feels* like. Emotionally specific but
//  non-medical personalization input. Single-select. Replaces the old generic
//  PersonalGoal screen in the new flow — it is its own answer, not a goal. Raw
//  values are stable and persisted, so cases must only ever be appended.
//

import Foundation

enum DelayConsequence: String, CaseIterable, Hashable, Identifiable {
    case stressful
    case annoying
    case scary
    case overthink
    case doubleCheck
    case dontCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stressful: return "Stressful"
        case .annoying: return "Annoying"
        case .scary: return "Scary"
        case .overthink: return "I overthink it"
        case .doubleCheck: return "I have to double-check"
        case .dontCare: return "I don't care much"
        }
    }

    /// Positive desired-outcome wording used by the consolidated intent screen.
    /// The persisted cases stay unchanged, preserving the diagnosis semantics for
    /// existing answers while asking new users one clearer combined question.
    var desiredOutcomeTitle: String {
        switch self {
        case .stressful: return "Less stress"
        case .annoying: return "Fewer interruptions"
        case .scary: return "More reassurance"
        case .overthink: return "Peace of mind"
        case .doubleCheck: return "Confidence it's done"
        case .dontCare: return "A simpler routine"
        }
    }

    var symbolName: String {
        switch self {
        case .stressful: return "wind"
        case .annoying: return "exclamationmark.bubble.fill"
        case .scary: return "exclamationmark.triangle.fill"
        case .overthink: return "arrow.triangle.2.circlepath"
        case .doubleCheck: return "checkmark.circle.badge.questionmark"
        case .dontCare: return "hand.wave.fill"
        }
    }
}

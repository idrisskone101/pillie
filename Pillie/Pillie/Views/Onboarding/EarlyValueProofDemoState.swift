//
//  EarlyValueProofDemoState.swift
//  Pillie
//
//  UI-free interaction state for the Catch the Drift demo (#206).
//

import Foundation

enum EarlyValueProofDemoCompletion: Equatable {
    case accessibility
    case interactive
    case skip
    case tapFallback
}

enum EarlyValueProofDemoAction: Equatable {
    case drag(progress: Double)
    case primary
    case shake(count: Int, required: Int)
    case skip
}

enum EarlyValueProofDemoOutcome: Equatable {
    case noChange
    case latched
    case unlatched
    case resolved(EarlyValueProofDemoCompletion)
    case advance(EarlyValueProofDemoCompletion)
}

enum EarlyValueProofDemoPrimaryAction: Equatable {
    case checkInFallback
    case continueOnboarding
}

struct EarlyValueProofDemoState: Equatable {
    private var reduceMotion: Bool
    private var voiceOverEnabled: Bool
    private(set) var isLatched = false
    private(set) var isResolved = false
    private(set) var completion: EarlyValueProofDemoCompletion?

    init(reduceMotion: Bool = false, voiceOverEnabled: Bool = false) {
        self.reduceMotion = reduceMotion
        self.voiceOverEnabled = voiceOverEnabled
    }

    /// The idle demo is intentionally drag-only. Exposing no primary action keeps
    /// the view from rendering button chrome for instructional copy.
    var primaryAction: EarlyValueProofDemoPrimaryAction? {
        if completion != nil || reduceMotion || voiceOverEnabled {
            return .continueOnboarding
        }
        if isLatched {
            return .checkInFallback
        }
        return nil
    }

    mutating func updateAccessibility(reduceMotion: Bool, voiceOverEnabled: Bool) {
        self.reduceMotion = reduceMotion
        self.voiceOverEnabled = voiceOverEnabled
    }

    mutating func handle(_ action: EarlyValueProofDemoAction) -> EarlyValueProofDemoOutcome {
        switch action {
        case .drag(let progress):
            if !isLatched, progress >= 0.72 {
                isLatched = true
                return .latched
            }
            if isLatched, progress <= 0.60 {
                isLatched = false
                return .unlatched
            }
            return .noChange
        case .primary:
            if let completion { return .advance(completion) }
            if reduceMotion || voiceOverEnabled { return .advance(.accessibility) }
            guard isLatched else { return .noChange }
            isResolved = true
            completion = .tapFallback
            return .resolved(.tapFallback)
        case .shake(let count, let required):
            guard !isResolved, isLatched, count >= required else { return .noChange }
            isResolved = true
            completion = .interactive
            return .resolved(.interactive)
        case .skip:
            return .advance(.skip)
        }
    }
}

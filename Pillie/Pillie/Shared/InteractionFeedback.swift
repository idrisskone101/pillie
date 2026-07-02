//
//  InteractionFeedback.swift
//  Pillie
//

import Foundation
#if os(iOS)
import UIKit
#endif

protocol InteractionFeedbackPerforming: AnyObject {
    func perform(_ intent: InteractionFeedback.Intent)
}

struct InteractionFeedback {
    enum Intent: Equatable {
        case tabChange
        case choice
        case lowRiskTap
        case meaningfulCommit
        case success
        case rareHighEnergy
    }

    static let live = InteractionFeedback(performer: UIKitInteractionFeedbackPerformer())

    private let performer: InteractionFeedbackPerforming

    init(performer: InteractionFeedbackPerforming) {
        self.performer = performer
    }

    func perform(_ intent: Intent) {
        performer.perform(intent)
    }
}

final class UIKitInteractionFeedbackPerformer: InteractionFeedbackPerforming {
    #if os(iOS)
    // Reused generators: firing a haptic must not pay allocation + Taptic Engine
    // setup on the main thread, because that cost lands on the exact frame an
    // interaction's animation starts (e.g. the tab-switch slide).
    private let selection = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    func perform(_ intent: InteractionFeedback.Intent) {
        #if os(iOS)
        switch intent {
        case .tabChange, .choice:
            selection.selectionChanged()
        case .lowRiskTap:
            lightImpact.impactOccurred()
        case .meaningfulCommit:
            mediumImpact.impactOccurred()
        case .success:
            notification.notificationOccurred(.success)
        case .rareHighEnergy:
            heavyImpact.impactOccurred()
        }
        #endif
    }
}

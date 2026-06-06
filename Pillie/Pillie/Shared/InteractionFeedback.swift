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
    func perform(_ intent: InteractionFeedback.Intent) {
        #if os(iOS)
        switch intent {
        case .tabChange, .choice:
            UISelectionFeedbackGenerator().selectionChanged()
        case .lowRiskTap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .meaningfulCommit:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .rareHighEnergy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        #endif
    }
}

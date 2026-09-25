//
//  BlockingStatusPresentation.swift
//  Pillie
//
//  Drives the "enable app blocking later" surface shown after Reminder-Only
//  Onboarding Completion. Pure presentation logic (no SwiftUI) so the labeling and
//  routing contract is testable as a value type. See CONTEXT.md / ADR 0003: the
//  completion/home state must label app blocking incomplete and offer a clear path
//  to enable it, without describing Plus-but-reminder-only users as free.
//

import Foundation

/// Which blocking-status surface to show, derived from the completion classification.
enum BlockingStatusPresentation: Equatable {
    /// App blocking is activated and running — no setup prompt.
    case active
    /// Reminder-only with a Plus entitlement: offer to finish Screen Time setup.
    case incompleteEntitled
    /// Reminder-only without entitlement: offer to unlock blocking with Plus.
    case incompleteFree

    static func make(
        outcome: ProtectionPlanCompletion.Outcome,
        isEntitled: Bool
    ) -> BlockingStatusPresentation {
        switch outcome {
        case .protectionPlanActivated:
            return .active
        case .reminderOnly:
            return isEntitled ? .incompleteEntitled : .incompleteFree
        }
    }

    /// Whether to surface the enable-blocking-later prompt (the Home card).
    var showsEnableBlockingPrompt: Bool {
        self != .active
    }
}

/// Copy for the enable-blocking-later card. `nil` when blocking is already active.
struct BlockingStatusCardContent: Equatable {
    let title: String
    let detail: String
    let ctaTitle: String
    /// Whether to show the Plus lock affordance (free users route to the paywall;
    /// entitled users route straight to Screen Time setup).
    let isLocked: Bool

    var visibleCopy: [String] { [title, detail, ctaTitle] }

    static func make(
        for presentation: BlockingStatusPresentation,
        method: ContraceptiveMethod = .pill,
        action: DoseScheduleAction? = nil,
        locale: Locale = .current
    ) -> BlockingStatusCardContent? {
        switch presentation {
        case .active:
            return nil
        case .incompleteEntitled:
            return BlockingStatusCardContent(
                title: PillieLocalization.string(
                    "today.protection.setup.title",
                    locale: locale
                ),
                detail: PillieLocalization.string(
                    MethodAwareCopy.key(.todaySetup, action: action, method: method),
                    locale: locale
                ),
                ctaTitle: PillieLocalization.string(
                    "today.protection.setup.cta",
                    locale: locale
                ),
                isLocked: false
            )
        case .incompleteFree:
            return BlockingStatusCardContent(
                title: PillieLocalization.string(
                    "today.protection.inactive",
                    locale: locale
                ),
                detail: PillieLocalization.string(
                    MethodAwareCopy.key(.todayOff, action: action, method: method),
                    locale: locale
                ),
                ctaTitle: PillieLocalization.string(
                    "today.protection.add",
                    locale: locale
                ),
                isLocked: true
            )
        }
    }
}

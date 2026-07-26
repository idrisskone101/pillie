//
//  ContraceptiveMethod.swift
//  Pillie
//

import Foundation

enum ContraceptiveMethod: String, CaseIterable, Codable {
    case pill
    case patch
    case ring

    var title: String {
        localizedTitle()
    }

    func localizedTitle(locale: Locale = .current) -> String {
        switch self {
        case .pill: return PillieLocalization.string("global.method.pill", locale: locale)
        case .patch: return PillieLocalization.string("global.method.patch", locale: locale)
        case .ring: return PillieLocalization.string("global.method.ring", locale: locale)
        }
    }

    var emoji: String {
        switch self {
        case .pill: return "\u{1F48A}"
        case .patch: return "\u{1FA79}"
        case .ring: return "\u{1F48D}"
        }
    }

    var blockingReasonText: String {
        blockingReasonText()
    }

    func blockingReasonText(locale: Locale = .current) -> String {
        PillieLocalization.string("shield.blocking_reason", locale: locale)
    }

    var subtitle: String {
        switch self {
        case .pill: return "Daily \u{2022} all common regimens + custom"
        case .patch: return "Change weekly x3, then 1 week off"
        case .ring: return "Insert day 1, remove day 22, reinsert after 7 days"
        }
    }

    /// Short, plain-language descriptor for the Routine Basics Method cards (#77).
    /// Cleaner than `subtitle` so the first routine screen stays uncluttered.
    var routineDescriptor: String {
        localizedRoutineDescriptor()
    }

    func localizedRoutineDescriptor(locale: Locale = .current) -> String {
        switch self {
        case .pill:
            return PillieLocalization.string("onboarding.method.pill.subtitle", locale: locale)
        case .patch:
            return PillieLocalization.string("onboarding.method.patch.subtitle", locale: locale)
        case .ring:
            return PillieLocalization.string("onboarding.method.ring.subtitle", locale: locale)
        }
    }
}

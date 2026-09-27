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

    /// Quiver 3D icon asset name (Assets.xcassets/MethodIcons). Single source of
    /// truth for the method row icon on the onboarding method step (ENG-138); other
    /// screens that still hardcode their own SF Symbol are untouched.
    var iconImageName: String {
        switch self {
        case .pill: return "MethodIconPill"
        case .patch: return "MethodIconPatch"
        case .ring: return "MethodIconRing"
        }
    }

    /// Paper spec: pill renders at 32x32pt, patch and ring at 36x36pt, inside the
    /// same 44x44pt tile.
    var iconImageSize: CGFloat {
        switch self {
        case .pill: return 32
        case .patch, .ring: return 36
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

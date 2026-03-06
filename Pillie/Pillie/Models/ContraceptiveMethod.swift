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
        switch self {
        case .pill: return "The Pill"
        case .patch: return "The Patch"
        case .ring: return "The Ring"
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
        switch self {
        case .pill: return "Time to take your pill!"
        case .patch: return "Time for your patch change!"
        case .ring: return "Time for your ring action!"
        }
    }

    var subtitle: String {
        switch self {
        case .pill: return "Daily \u{2022} all common regimens + custom"
        case .patch: return "Change weekly x3, then 1 week off"
        case .ring: return "Insert day 1, remove day 21, reinsert day 28"
        }
    }
}

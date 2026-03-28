//
//  MissFrequency.swift
//  Pillie
//

import Foundation

enum MissFrequency: String, CaseIterable, Hashable, Identifiable {
    case rarely
    case sometimes
    case often
    case almostDaily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rarely: return "Rarely"
        case .sometimes: return "Sometimes"
        case .often: return "Often"
        case .almostDaily: return "Almost daily"
        }
    }

    var subtitle: String {
        switch self {
        case .rarely: return "Once a month or less"
        case .sometimes: return "About once a week"
        case .often: return "A few times a week"
        case .almostDaily: return "More often than I'd like"
        }
    }

    var emoji: String {
        switch self {
        case .rarely: return "\u{2705}"
        case .sometimes: return "\u{1F62C}"
        case .often: return "\u{1F630}"
        case .almostDaily: return "\u{1F198}"
        }
    }
}

//
//  PersonalGoal.swift
//  Pillie
//

import Foundation

enum PersonalGoal: String, CaseIterable, Hashable, Identifiable {
    case stayProtected
    case hormonalBalance
    case peaceOfMind
    case buildRoutine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stayProtected: return "Stay protected"
        case .hormonalBalance: return "Hormonal balance"
        case .peaceOfMind: return "Peace of mind"
        case .buildRoutine: return "Build a routine"
        }
    }

    var subtitle: String {
        switch self {
        case .stayProtected: return "Never risk a missed dose"
        case .hormonalBalance: return "Keep my cycle steady"
        case .peaceOfMind: return "Stop worrying if I took it"
        case .buildRoutine: return "Make it automatic"
        }
    }

    var emoji: String {
        switch self {
        case .stayProtected: return "\u{1F6E1}\u{FE0F}"
        case .hormonalBalance: return "\u{2696}\u{FE0F}"
        case .peaceOfMind: return "\u{1F9D8}"
        case .buildRoutine: return "\u{1F4C5}"
        }
    }
}

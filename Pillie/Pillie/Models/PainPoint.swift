//
//  PainPoint.swift
//  Pillie
//

import Foundation

enum PainPoint: String, CaseIterable, Hashable, Identifiable {
    case forgetful
    case chaoticSchedule
    case phoneDistractions
    case noRoutine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forgetful: return "I simply forget"
        case .chaoticSchedule: return "Chaotic schedule"
        case .phoneDistractions: return "Phone distractions"
        case .noRoutine: return "No set routine"
        }
    }

    var subtitle: String {
        switch self {
        case .forgetful: return "It slips my mind every day"
        case .chaoticSchedule: return "No two days look the same"
        case .phoneDistractions: return "I get lost in apps"
        case .noRoutine: return "I haven't built the habit yet"
        }
    }

    var emoji: String {
        switch self {
        case .forgetful: return "🧠"
        case .chaoticSchedule: return "🌀"
        case .phoneDistractions: return "📱"
        case .noRoutine: return "🔄"
        }
    }
}

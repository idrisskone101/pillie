//
//  RiskWindow.swift
//  Pillie
//
//  A committed Protection Plan Onboarding answer (PRD #72, issue #76): when the
//  user is most likely to drift into a distracting app after a reminder.
//  Single-select. In v1 this is personalization / copy only — it deliberately
//  carries no scheduling surface and never changes the real blocking schedule.
//  Raw values are stable and persisted, so cases must only ever be appended.
//

import Foundation

enum RiskWindow: String, CaseIterable, Hashable, Identifiable {
    case rightAfterAlarm
    case withinFiveMinutes
    case laterInDay
    case randomly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightAfterAlarm: return "Right after the alarm"
        case .withinFiveMinutes: return "Within 5 minutes"
        case .laterInDay: return "Later in the day"
        case .randomly: return "Randomly"
        }
    }

    var subtitle: String {
        switch self {
        case .rightAfterAlarm: return "The danger zone"
        case .withinFiveMinutes: return "The slow drift"
        case .laterInDay: return "After the morning rush"
        case .randomly: return "No specific pattern"
        }
    }
}

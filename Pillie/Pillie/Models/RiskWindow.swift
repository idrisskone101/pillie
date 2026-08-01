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
        localizedTitle()
    }

    func localizedTitle(locale: Locale = .current) -> String {
        let key: String
        switch self {
        case .rightAfterAlarm: key = "onboarding.risk_window.right_after"
        case .withinFiveMinutes: key = "onboarding.risk_window.within_five"
        case .laterInDay: key = "onboarding.risk_window.later"
        case .randomly: key = "onboarding.risk_window.random"
        }
        return PillieLocalization.string(key, locale: locale)
    }

    var subtitle: String {
        localizedSubtitle()
    }

    func localizedSubtitle(locale: Locale = .current) -> String {
        PillieLocalization.string("onboarding.risk_window.subtitle", locale: locale)
    }
}

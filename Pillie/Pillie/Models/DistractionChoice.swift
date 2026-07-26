//
//  DistractionChoice.swift
//  Pillie
//
//  A committed Protection Plan Onboarding answer (PRD #72, issue #75): what
//  usually gets in the way after a reminder. Multi-select, including an Other
//  catch-all. Kept distinct from `AcquisitionSource` — "TikTok as a distraction"
//  and "TikTok as a source" are different concepts. Raw values are stable and
//  persisted, so cases must only ever be appended.
//

import Foundation

enum DistractionChoice: String, CaseIterable, Hashable, Identifiable {
    case tiktok
    case instagram
    case youtube
    case messages
    case snooze
    case busy
    case forget
    case other

    var id: String { rawValue }

    /// Whether this is the Other catch-all, which always sorts last and is the
    /// only option whose meaning is "something Pillie didn't name".
    var isOther: Bool { self == .other }

    var title: String {
        let key: String
        switch self {
        case .tiktok: key = "onboarding.personalise.choice.tiktok"
        case .instagram: key = "onboarding.personalise.choice.instagram"
        case .youtube: key = "onboarding.personalise.choice.youtube"
        case .messages: key = "onboarding.personalise.choice.messages"
        case .snooze: key = "onboarding.personalise.choice.snooze"
        case .busy: key = "onboarding.personalise.choice.busy"
        case .forget: key = "onboarding.personalise.choice.forget"
        case .other: key = "onboarding.personalise.choice.other"
        }
        return PillieLocalization.string(key)
    }

    var symbolName: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .youtube: return "play.rectangle.fill"
        case .messages: return "message.fill"
        case .snooze: return "moon.zzz.fill"
        case .busy: return "hourglass"
        case .forget: return "brain.head.profile"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

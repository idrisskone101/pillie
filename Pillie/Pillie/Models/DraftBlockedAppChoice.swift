//
//  DraftBlockedAppChoice.swift
//  Pillie
//
//  A committed Protection Plan Onboarding answer (PRD #72, issue #76): the apps and
//  broad distraction categories the user *intends* Pillie to block during pill time.
//  Multi-select and grouped (categories, then specific apps, then an Other
//  catch-all). This is a DRAFT intent only — it is deliberately kept separate from
//  the real FamilyControls / Screen Time app selection, which happens later with
//  Apple's own picker and stores opaque tokens. These are plain, low-cardinality
//  labels with no app tokens. Raw values are stable and persisted, so cases must
//  only ever be appended.
//

import Foundation

enum DraftBlockedAppChoice: String, CaseIterable, Hashable, Identifiable {
    /// Which rendered section a choice belongs to.
    enum Group: String {
        case category
        case app
        case other
    }

    // Broad distraction categories.
    case shortVideos
    case socialFeeds
    case messages
    case games
    // Specific apps.
    case tiktok
    case instagram
    case youtube
    case x
    case snapchat
    // Catch-all for something Pillie didn't name.
    case other

    var id: String { rawValue }

    /// Whether this is the Other catch-all, which always sorts last.
    var isOther: Bool { self == .other }

    /// The broad distraction categories, in display order.
    static let categories: [DraftBlockedAppChoice] = [.shortVideos, .socialFeeds, .messages, .games]

    /// The specific apps, in display order.
    static let apps: [DraftBlockedAppChoice] = [.tiktok, .instagram, .youtube, .x, .snapchat]

    var group: Group {
        if isOther { return .other }
        if Self.categories.contains(self) { return .category }
        return .app
    }

    var title: String {
        switch self {
        case .shortVideos: return "Short videos"
        case .socialFeeds: return "Social feeds"
        case .messages: return "Messages"
        case .games: return "Games"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        case .x: return "X"
        case .snapchat: return "Snapchat"
        case .other: return "Other"
        }
    }

    /// A generic, App-Store-safe SF Symbol (never a brand mark). Used only by the
    /// draft-plan summary tokens for a little visual texture — the selectable chips
    /// themselves stay text-only.
    var symbolName: String {
        switch self {
        case .shortVideos: return "play.rectangle.fill"
        case .socialFeeds: return "rectangle.stack.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .games: return "gamecontroller.fill"
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .youtube: return "play.tv.fill"
        case .x: return "number"
        case .snapchat: return "bolt.fill"
        case .other: return "ellipsis"
        }
    }
}
